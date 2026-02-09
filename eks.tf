# EKS Cluster - Completely Private
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "rancher-eks-${var.environment}"
  cluster_version = "1.35"

  # Completely Private Cluster - No public endpoint
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  # Use existing VPC
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Cluster encryption
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # Cluster addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    # Standard Node Group
    standard = {
      name = "standard-ng"

      # Instance type with 2 vCPU and 4 GB RAM
      instance_types = ["t3.medium"]
      
      capacity_type = "ON_DEMAND"

      min_size     = 2
      max_size     = 5
      desired_size = 2

      # Disk configuration
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # Use private subnets
      subnet_ids = module.vpc.private_subnets

      # Labels
      labels = {
        Environment = var.environment
        NodeGroup   = "standard"
        ManagedBy   = "Terraform"
      }

      # Tags
      tags = {
        Name        = "rancher-eks-standard-${var.environment}"
        Environment = var.environment
      }
    }
  }

  # Cluster security group additional rules
  cluster_security_group_additional_rules = {
    # Allow HTTPS from Rancher EC2 instance
    ingress_ec2_https = {
      description              = "HTTPS from Rancher EC2"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      source_security_group_id = aws_security_group.ec2_ssh.id
    }
  }

  # Node security group additional rules
  node_security_group_additional_rules = {
    # Allow HTTPS from Rancher EC2 to nodes
    ingress_ec2_https = {
      description              = "HTTPS from Rancher EC2"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      source_security_group_id = aws_security_group.ec2_ssh.id
    }

    # Allow all traffic between nodes
    ingress_self_all = {
      description = "Node to node all traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    # Allow all outbound
    egress_all = {
      description = "Node all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Cluster tags
  tags = {
    Name        = "rancher-eks-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# KMS Key for EKS cluster encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "eks-secret-encryption-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/eks-${var.environment}"
  target_key_id = aws_kms_key.eks.key_id
}

# Note: Rancher EC2 access to EKS API is configured in cluster_security_group_additional_rules above

