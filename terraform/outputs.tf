output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.rate_limiter.public_ip
}

output "instance_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.rate_limiter.public_dns
}
