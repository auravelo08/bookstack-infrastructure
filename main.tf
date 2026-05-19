############################################
# VPC
############################################
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-bookstack"
  }
}

############################################
# Internet Gateway
############################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-bookstack"
  }
}

############################################
# Public Subnets
############################################
resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 4, count.index)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-${var.azs[count.index]}"
  }
}

############################################
# Private Subnets
############################################
resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 4, count.index + 10)
  availability_zone = var.azs[count.index]

  tags = {
    Name = "private-${var.azs[count.index]}"
  }
}

############################################
# Public Route Table
############################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

############################################
# Private Route Table (empty)
############################################
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-rt"
  }
}

############################################
# NAT Instance
############################################
resource "aws_security_group" "fck_nat_sg" {
  name        = "fck-nat-sg"
  description = "Allow VPC traffic for NAT"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "fck_nat" {
  ami                    = "ami-0b5a4e51202cd98e5" # Amazon Linux 2
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[0].id
  source_dest_check      = false
  vpc_security_group_ids = [aws_security_group.fck_nat_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    sysctl -w net.ipv4.ip_forward=1
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  EOF

  tags = {
    Name = "fck-nat"
  }
}

resource "aws_eip" "fck_nat_eip" {
  instance = aws_instance.fck_nat.id

  tags = {
    Name = "fck-nat-eip"
  }
}

############################################
# ENI Lookup for NAT Instance (Terraform v5 requirement)
############################################
data "aws_network_interface" "fck_nat_eni" {
  filter {
    name   = "attachment.instance-id"
    values = [aws_instance.fck_nat.id]
  }
}

############################################
# Private Route → NAT ENI
############################################
resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = data.aws_network_interface.fck_nat_eni.id

  depends_on = [aws_instance.fck_nat]
}

resource "aws_route_table_association" "private_assoc" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
