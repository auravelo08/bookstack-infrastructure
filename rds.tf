# --- 1. GROUPE DE SOUS-RÉSEAUX RDS ---
resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "shared-rds-subnet-group"
  description = "Subnet group for shared RDS (Prod and Staging)"
  subnet_ids  = [aws_subnet.private[0].id, aws_subnet.private[1].id]

  tags = {
    Name = "shared-rds-subnet-group"
  }
}

# --- 2. SECURITY GROUP DU RDS ---
resource "aws_security_group" "rds_sg" {
  name        = "shared-rds-sg"
  description = "Allow database traffic from Prod Swarm and Staging EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "MySQL/MariaDB from Prod Swarm nodes and runner"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [
      aws_security_group.swarm_nodes.id,
      aws_security_group.gitlab_runner_sg.id
    ]
  }

  #   # Accès depuis ton instance unique de Staging
  #   ingress {
  #     description     = "PostgreSQL from Staging EC2"
  #     from_port       = 5432
  #     to_port         = 5432
  #     protocol        = "tcp"
  #     security_groups = [aws_security_group.staging_sg.id] # <- À adapter avec le nom de ton SG Staging
  #   }

  #   egress {
  #     from_port   = 0
  #     to_port     = 0
  #     protocol    = "-1"
  #     cidr_blocks = ["0.0.0.0/0"]
  #   }

  tags = {
    Name = "shared-rds-sg"
  }
}

# --- 3. L'INSTANCE RDS PHYSIQUE ---
resource "aws_db_instance" "shared_rds" {
  identifier            = "shared-bookstack-keycloak-rds"
  allocated_storage     = 20
  max_allocated_storage = 50

  # Changements ici :
  engine         = "mariadb"
  engine_version = "10.11" # Version stable actuelle de MariaDB
  instance_class = "db.t3.micro"

  username = "dbadmin"
  password = var.rds_master_password

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Important pour MySQL/MariaDB
  port = 3306

  publicly_accessible = false
  multi_az            = false
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "shared-rds"
    Environment = "shared"
  }
}
