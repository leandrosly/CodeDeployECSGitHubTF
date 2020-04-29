output "vpc_arn" {
  value       = aws_vpc.vpc-dev.arn
  description = ""
}

output "vpc_id" {
  value       = aws_vpc.vpc-dev.id
  description = ""
}

output "vpc_cidr_block" {
  value       = aws_vpc.vpc-dev.cidr_block
  description = ""
}

output "vpc_main_route_table_id" {
  value       = aws_vpc.vpc-dev.main_route_table_id
  description = ""
}

output "vpc_default_network_acl_id" {
  value       = aws_vpc.vpc-dev.default_network_acl_id
  description = ""
}

output "vpc_default_security_group_id" {
  value       = aws_vpc.vpc-dev.default_security_group_id
  description = ""
}

output "vpc_default_route_table_id" {
  value       = aws_vpc.vpc-dev.default_route_table_id
  description = ""
}

output "ecs_cluster_arn" {
  value       = aws_ecs_cluster.cluster.arn
  description = ""
}

output "ecs_cluster_id" {
  value       = aws_ecs_cluster.cluster.id
  description = ""
}

output "alb_id" {
  value       = aws_lb.alb.id
  description = ""
}

output "alb_arn" {
  value       = aws_lb.alb.arn
  description = ""
}

output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = ""
}
