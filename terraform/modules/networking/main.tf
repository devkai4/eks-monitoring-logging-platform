variable "project_name" {
  description = "Project name to be used as a prefix for all resources"
  type        = string
}

provider "aws" {
  region = var.region
}

locals {
  name = "${var.project_name}-${var.environment}"
  
  tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-vpc"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-igw"
    }
  )
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0
  domain = "vpc"

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-eip-nat-${count.index + 1}"
    }
  )
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.tags,
    {
      Name                                           = "${local.name}-public-${var.azs[count.index]}"
      "kubernetes.io/role/elb"                       = 1
      "kubernetes.io/cluster/${local.name}-cluster"  = "shared"
    }
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(
    local.tags,
    {
      Name                                           = "${local.name}-private-${var.azs[count.index]}"
      "kubernetes.io/role/internal-elb"              = 1
      "kubernetes.io/cluster/${local.name}-cluster"  = "shared"
    }
  )
}

# NAT Gateway
resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-nat-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.this]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-rt-public"
    }
  )
}

# Public Route
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Route Table association with Public Subnets
resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables
resource "aws_route_table" "private" {
  count = var.single_nat_gateway ? 1 : length(var.azs)

  vpc_id = aws_vpc.this.id

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-rt-private-${count.index + 1}"
    }
  )
}

# Private Routes (through NAT Gateway)
resource "aws_route" "private_nat_gateway" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

# Route Table association with Private Subnets
resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}

# VPC Endpoint for S3 (Gateway)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat([aws_route_table.public.id], aws_route_table.private[*].id)

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-s3-endpoint"
    }
  )
}

# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster" {
  name        = "${local.name}-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.this.id

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-eks-cluster-sg"
    }
  )
}

# Security Group for EKS Node Group
resource "aws_security_group" "eks_nodes" {
  name        = "${local.name}-eks-nodes-sg"
  description = "Security group for EKS nodes"
  vpc_id      = aws_vpc.this.id

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-eks-nodes-sg"
    }
  )
}

# Security Group Rules for EKS Cluster
resource "aws_security_group_rule" "cluster_inbound" {
  description              = "Allow worker nodes to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

resource "aws_security_group_rule" "cluster_outbound" {
  description              = "Allow cluster API Server to communicate with the worker nodes"
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_cluster.id
  cidr_blocks              = ["0.0.0.0/0"]
}

# Security Group Rules for EKS Node Group
resource "aws_security_group_rule" "nodes_inbound" {
  description              = "Allow nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

resource "aws_security_group_rule" "nodes_cluster_inbound" {
  description              = "Allow worker nodes to receive communication from the cluster control plane"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "nodes_outbound" {
  description = "Allow all outbound traffic"
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes.id
}