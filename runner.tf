resource "aws_security_group" "gitlab_runner_sg" {
  name        = "gitlab-runner-sg"
  description = "Allow SSH only from bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
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
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.gitlab_runner_sg.id]
  key_name               = "bs-caps-project"

  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.gitlab_runner_profile.name

  root_block_device {
    volume_size = 30 # ← mets 30 ou 50 Go selon tes builds
    volume_type = "gp3"
  }

  lifecycle {
    ignore_changes = [
      ami,
      instance_type,
      user_data,
      # Ajoutez ici tous les champs qui changent souvent
    ]
  }

  tags = {
    Name        = "gitlab-runner"
    Project     = "BookStack"
    Environment = "Multi-Env"
    ManagedBy   = "Terraform"
  }
}

# 1. Création de la politique avec les droits nécessaires
resource "aws_iam_policy" "gitlab_runner_policy" {
  name        = "gitlab-runner-full-infra-policy"
  description = "Permissions pour que le runner puisse déployer l'infra"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "s3:*",
          "elasticloadbalancing:*",
          "rds:*",
          "iam:Get*",
          "iam:List*",
          "iam:PassRole",
          "cloudfront:*",
          "vpc:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# 2. Attachement au rôle existant
resource "aws_iam_role_policy_attachment" "gitlab_runner_infra_access" {
  role       = aws_iam_role.gitlab_runner_role.name
  policy_arn = aws_iam_policy.gitlab_runner_policy.arn
}
