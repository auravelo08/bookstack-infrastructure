data "aws_ami" "fck_nat" {
  most_recent = true
  owners      = ["568608671756"] # ID du compte officiel de fck-nat

  filter {
    name   = "name"
    values = ["fck-nat-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

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
  ami                    = data.aws_ami.fck_nat.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[0].id
  source_dest_check      = false
  vpc_security_group_ids = [aws_security_group.fck_nat_sg.id]

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

data "aws_network_interface" "fck_nat_eni" {
  filter {
    name   = "attachment.instance-id"
    values = [aws_instance.fck_nat.id]
  }
}

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
