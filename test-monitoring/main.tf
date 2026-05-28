# 1. Le Réseau (VPC)
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "prometheus-vpc" }
}

# 2. Le Sous-réseau (Subnet)
resource "aws_subnet" "main_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false # Indispensable pour avoir une IP publique

  tags = { Name = "prometheus-subnet" }
}

# 3. La Passerelle Internet (Internet Gateway)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = { Name = "prometheus-igw" }
}

# 4. La Table de Routage (Pour sortir vers Internet)
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.rt.id
}

# 5. Le Security Group (lié au nouveau VPC)
resource "aws_security_group" "prom_sg" {
  name   = "prometheus-sg"
  vpc_id = aws_vpc.main_vpc.id # Liaison au VPC créé ci-dessus

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["185.146.221.142/32"] # Votre IP pour SSH
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["185.146.221.142/32"] # Votre IP pour SSH
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["185.146.221.142/32"] # Votre IP pour SSH
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["185.146.221.142/32"] # Votre IP pour SSH
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 6. L'Instance EC2
resource "aws_instance" "ubuntu" {
  ami                    = "ami-0adb8ca49015e0901"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.main_subnet.id # Placement dans le subnet
  vpc_security_group_ids = [aws_security_group.prom_sg.id]
  key_name               = "grafana"

  tags = { Name = "test-prometheus" }
}