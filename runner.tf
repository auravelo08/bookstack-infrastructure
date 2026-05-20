resource "aws_security_group" "gitlab_runner_sg" {
  name        = "gitlab-runner-sg"
  description = "Allow SSH only from bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["sg-013b500e2824b95ba"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gitlab-runner-sg"
  }
}

resource "aws_iam_role" "gitlab_runner_role" {
  name = "gitlab-runner-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "gitlab_runner_basic" {
  role       = aws_iam_role.gitlab_runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "gitlab_runner_profile" {
  name = "gitlab-runner-profile"
  role = aws_iam_role.gitlab_runner_role.name
}

resource "aws_instance" "gitlab_runner" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.gitlab_runner_sg.id]
  key_name               = "bs-caps-project"

  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.gitlab_runner_profile.name

  root_block_device {
    volume_size = 30 # ← mets 30 ou 50 Go selon tes builds
    volume_type = "gp3"
  }

  tags = {
    Name        = "gitlab-runner"
    Project     = "BookStack"
    Environment = "Multi-Env"
    ManagedBy   = "Terraform"
  }
}
