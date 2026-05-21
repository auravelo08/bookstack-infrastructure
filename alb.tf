############################################
# ALB Security Group
############################################
resource "aws_security_group" "alb_sg" {
  name        = "bookstack-alb-sg"
  description = "Allow inbound HTTP traffic from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# Application Load Balancer
############################################
resource "aws_lb" "bookstack_alb" {
  name               = "bookstack-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "bookstack_tg" {
  name     = "bookstack-tg"
  port     = 6875
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/login"
    port                = 6875
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

# Attacher les 3 instances du cluster Swarm au Target Group
resource "aws_lb_target_group_attachment" "swarm_nodes" {
  count            = 3
  target_group_arn = aws_lb_target_group.bookstack_tg.arn
  target_id        = aws_instance.swarm_nodes[count.index].id
  port             = 6875
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.bookstack_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bookstack_tg.arn
  }
}
