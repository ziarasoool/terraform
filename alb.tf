# Data source to get existing ACM certificate
data "aws_acm_certificate" "rancher" {
  domain   = "rancher.ziarasool.site"
  statuses = ["ISSUED"]
}

# Data source to get Route 53 hosted zone
data "aws_route53_zone" "main" {
  name         = "ziarasool.site."
  private_zone = false
}

# Security Group for ALB - HTTPS from everywhere
resource "aws_security_group" "alb" {
  name        = "alb-rancher-sg-${var.environment}"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from everywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from everywhere (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "alb-rancher-sg-${var.environment}"
    Environment = var.environment
  }
}

# Application Load Balancer
resource "aws_lb" "rancher" {
  name               = "rancher-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [module.vpc.public_subnets[0], module.vpc.public_subnets[1]]

  enable_deletion_protection = false
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name        = "rancher-alb-${var.environment}"
    Environment = var.environment
  }

  depends_on = [module.vpc]
}

# Target Group for Rancher (Port 80)
resource "aws_lb_target_group" "rancher" {
  name     = "rancher-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/healthz"
    protocol            = "HTTP"
    matcher             = "200-499"
  }

  deregistration_delay = 30

  tags = {
    Name        = "rancher-tg-${var.environment}"
    Environment = var.environment
  }
}

# Attach Rancher instance to Target Group
resource "aws_lb_target_group_attachment" "rancher" {
  target_group_arn = aws_lb_target_group.rancher.arn
  target_id        = aws_instance.rancher.id
  port             = 80

  depends_on = [aws_instance.rancher]
}

# ALB Listener - HTTPS (443) with SSL Certificate
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.rancher.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.rancher.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rancher.arn
  }

  tags = {
    Name        = "rancher-https-listener"
    Environment = var.environment
  }
}

# ALB Listener - HTTP (80) - Redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.rancher.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name        = "rancher-http-listener"
    Environment = var.environment
  }
}

# Route 53 Record - CNAME pointing rancher.ziarasool.site to ALB
resource "aws_route53_record" "rancher" {
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = "rancher.ziarasool.site"
  type            = "CNAME"
  ttl             = 300
  records         = [aws_lb.rancher.dns_name]
  allow_overwrite = true
}

