# =========================================================================
# 1. LE RÉSEAU UNIQUE (VPC & SUBNETS)
# =========================================================================

resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "test-bdd-vpc" }
}

# Internet Gateway pour permettre les flux vers l'extérieur
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id
  tags   = { Name = "test-bdd-igw" }
}

# Table de routage pour le réseau
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# Sous-réseau A (Où se trouve l'EC2 et une partie de RDS)
resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-3a"
  map_public_ip_on_launch = true # À activer si tu as besoin qu'Ansible la touche directement via Internet
  tags = { Name = "test-bdd-subnet-a" }
}

resource "aws_route_table_association" "assoc_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.rt.id
}

# Sous-réseau B (Obligatoire pour le Multi-AZ de RDS)
resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-3b"
  tags              = { Name = "test-bdd-subnet-b" }
}

resource "aws_route_table_association" "assoc_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.rt.id
}

# Groupe de sous-réseaux pour la base RDS
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-main-subnet-test-bdd"
  subnet_ids = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  tags       = { Name = "rds-subnet-group" }
}

# =========================================================================
# 2. LA SÉCURITÉ (SECURITY GROUPS)
# =========================================================================

# Security Group pour l'EC2
resource "aws_security_group" "prom_sg" {
  name   = "test_bdd-sg"
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["185.146.221.142/32"] # Ton IP pour SSH / Ansible
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["185.146.221.142/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Requis pour que le script joigne l'API AWS
  }
}

# Security Group pour RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds_test-private-sg"
  vpc_id      = aws_vpc.main_vpc.id
  description = "Pare-feu de la base de donnees"

  # Autorise l'EC2 à se connecter à la base PostgreSQL si nécessaire
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.prom_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# =========================================================================
# 3. L'IAM POUR L'EC2 (Gestion des Snapshots)
# =========================================================================

resource "aws_iam_role" "rds_snapshot_role" {
  name = "EC2-RDS-Snapshot-testdebdd"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy" "rds_snapshot_policy" {
  name = "EC2-RDS-Snapshot-Permissions"
  role = aws_iam_role.rds_snapshot_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:CreateDBSnapshot",
          "rds:DeleteDBSnapshot",
          "rds:DescribeDBSnapshots"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_rds_profile" {
  name = "ec2_rds_snapshot_testdebdd"
  role = aws_iam_role.rds_snapshot_role.name
}

# =========================================================================
# 4. LES RESSOURCES (EC2 & RDS)
# =========================================================================

resource "aws_instance" "ubuntu" {
  ami                    = "ami-0adb8ca49015e0901"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.subnet_a.id
  vpc_security_group_ids = [aws_security_group.prom_sg.id]
  key_name               = "grafana"
  iam_instance_profile   = aws_iam_instance_profile.ec2_rds_profile.name

  tags = { Name = "test-bdd" }
}

resource "aws_db_instance" "postgres" {
  identifier        = "mon-rds-testdebdd"
  allocated_storage = 20
  engine            = "postgres"
  engine_version    = "15.10"
  instance_class    = "db.t3.micro"

  db_name  = "test_bdd"
  username = "dbadmin"
  password = "bookstack" # Pense à utiliser une variable sensible ici ;)

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false

  backup_retention_period = 0
  skip_final_snapshot     = true

  tags = { Name = "rds-database-testdebdd" }
}