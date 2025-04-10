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
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0
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
      Name                                          = "${local.name}-public-${var.azs[count.index]}"
      "kubernetes.io/role/elb"                      = 1
      "kubernetes.io/cluster/${local.name}-cluster" = "shared"
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
      Name                                          = "${local.name}-private-${var.azs[count.index]}"
      "kubernetes.io/role/internal-elb"             = 1
      "kubernetes.io/cluster/${local.name}-cluster" = "shared"
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
