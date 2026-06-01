resource "aws_security_group" "swarm_nodes" {
  name        = "swarm-nodes-sg"
  description = "Allow Swarm internal communication"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description     = "Allow SSH from Gitlab Runner"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.gitlab_runner_sg.id]
  }

  ingress {
    from_port = 2377
    to_port   = 2377
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 7946
    to_port   = 7946
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 7946
    to_port   = 7946
    protocol  = "udp"
    self      = true
  }

  ingress {
    from_port = 4789
    to_port   = 4789
    protocol  = "udp"
    self      = true
  }

  ingress {
    description     = "Access to BookStack App"
    from_port       = 6875
    to_port         = 6875
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description     = "Traffic from ALB"
    from_port       = 6875
    to_port         = 6875
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Référence au SG du futur ALB
  }

  ingress {
    description     = "Traffic from ALB to Prometheus"
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description     = "Traffic from ALB to Grafana"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description     = "Traffic from ALB/Manager to Node Exporter"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Ou le SG du Manager si besoin
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "swarm-nodes-sg"
  }
}

resource "aws_instance" "swarm_nodes" {
  count = 3

  ami           = var.ami_id
  instance_type = "t3.small"
  subnet_id     = aws_subnet.private[count.index % length(aws_subnet.private)].id

  vpc_security_group_ids = [
    aws_security_group.swarm_nodes.id
  ]

  associate_public_ip_address = false
  key_name                    = var.keypair_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "swarm-node-${count.index + 1}"
    Role = count.index == 0 ? "manager" : "worker"
  }
}
