resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "shared-rds-subnet-group"
  description = "Subnet group for shared RDS (Prod and Staging)"
  subnet_ids  = [aws_subnet.private[0].id, aws_subnet.private[1].id]

  tags = {
    Name = "shared-rds-subnet-group"
  }
}

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

  tags = {
    Name = "shared-rds-sg"
  }
}

resource "aws_db_instance" "shared_rds" {
  identifier            = "shared-bookstack-keycloak-rds"
  allocated_storage     = 20
  max_allocated_storage = 50

  engine         = "mariadb"
  engine_version = "10.11"
  instance_class = "db.t3.micro"

  username = "dbadmin"
  password = var.rds_master_password

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

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
