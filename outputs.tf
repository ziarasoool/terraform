output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = module.vpc.natgw_ids
}

output "security_group_id" {
  description = "ID of the main security group"
  value       = aws_security_group.main.id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.igw_id
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "azs" {
  description = "Availability zones used"
  value       = module.vpc.azs
}

# EC2 Outputs
output "ec2_instance_id" {
  description = "ID of the Rancher EC2 instance"
  value       = aws_instance.rancher.id
}

output "ec2_private_ip" {
  description = "Private IP of the Rancher EC2 instance"
  value       = aws_instance.rancher.private_ip
}

output "ec2_public_ip" {
  description = "Public IP (EIP) of the Rancher EC2 instance"
  value       = aws_eip.rancher.public_ip
}

output "ec2_iam_role" {
  description = "IAM role attached to EC2 for secure EKS access"
  value       = aws_iam_role.rancher_ec2.name
}

output "ec2_iam_role_arn" {
  description = "IAM role ARN for EC2 instance"
  value       = aws_iam_role.rancher_ec2.arn
}

output "rancher_url" {
  description = "Rancher URL"
  value       = "https://${aws_eip.rancher.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to instance"
  value       = "ssh -i ~/.ssh/ranchers.pem ubuntu@${aws_eip.rancher.public_ip}"
}

output "rancher_security_group_id" {
  description = "Security Group ID for Rancher instance"
  value       = aws_security_group.ec2_ssh.id
}

# ALB Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.rancher.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.rancher.arn
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.rancher.zone_id
}

output "target_group_arn" {
  description = "ARN of the Target Group"
  value       = aws_lb_target_group.rancher.arn
}

output "rancher_domain" {
  description = "Rancher domain name"
  value       = "https://rancher.ziarasool.site"
}

output "alb_security_group_id" {
  description = "Security Group ID for ALB"
  value       = aws_security_group.alb.id
}

# EKS Outputs
output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane (private)"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "eks_node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

output "eks_oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = module.eks.oidc_provider_arn
}

output "eks_node_groups" {
  description = "EKS node groups information"
  value       = module.eks.eks_managed_node_groups
  sensitive   = true
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "configure_kubectl" {
  description = "Configure kubectl command"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

