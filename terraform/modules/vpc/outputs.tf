output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "cluster_security_group_id" {
  description = "The ID of the EKS cluster security group"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "The ID of the EKS node security group"
  value       = aws_security_group.nodes.id
}