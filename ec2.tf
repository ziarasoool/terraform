# Data source to get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source to get your current IP
data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

# Security Group for EC2 - SSH from your IP, HTTP/HTTPS from ALB only
resource "aws_security_group" "ec2_ssh" {
  name        = "rancher-ec2-sg-${var.environment}-v2"
  description = "Allow SSH from my IP, HTTP/HTTPS from ALB only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "rancher-ec2-sg-${var.environment}-v2"
    Environment = var.environment
  }
}

# Security Group Rules - Allow HTTP/HTTPS from ALB to EC2
resource "aws_security_group_rule" "ec2_http_from_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ec2_ssh.id
  source_security_group_id = aws_security_group.alb.id
  description              = "HTTP from ALB"
}

resource "aws_security_group_rule" "ec2_https_from_alb" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ec2_ssh.id
  source_security_group_id = aws_security_group.alb.id
  description              = "HTTPS from ALB"
}

# EC2 Instance - Ubuntu with Rancher
resource "aws_instance" "rancher" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  key_name      = "ranchers"

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ec2_ssh.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "rancher-root-volume"
    }
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Update system
              sudo apt update
              
              # Install Docker
              sudo apt install docker.io -y
              
              # Add ubuntu user to docker group
              sudo usermod -aG docker ubuntu
              
              # Start Docker service
              sudo systemctl enable docker
              sudo systemctl start docker
              
              # Install AWS CLI v2
              cd /tmp
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              sudo apt install unzip -y
              unzip awscliv2.zip
              sudo ./aws/install
              
              # Install kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
              
              # Cleanup
              rm -rf awscliv2.zip aws kubectl
              
              # Run Rancher container
              docker run -d --restart=unless-stopped \
                -p 80:80 -p 443:443 \
                --privileged \
                rancher/rancher:latest
              
              EOF

  tags = {
    Name        = "rancher-server-${var.environment}"
    Environment = var.environment
    Purpose     = "Rancher Management"
  }

  depends_on = [module.vpc]
}

# Elastic IP for EC2
resource "aws_eip" "rancher" {
  instance = aws_instance.rancher.id
  domain   = "vpc"

  tags = {
    Name        = "rancher-eip-${var.environment}"
    Environment = var.environment
  }

  depends_on = [aws_instance.rancher]
}

