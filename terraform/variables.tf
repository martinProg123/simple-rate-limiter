variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "ghcr_user" {
  description = "GitHub Container Registry username"
  type        = string
}

variable "ghcr_token" {
  description = "GitHub Container Registry token (classic PAT with read:packages)"
  type        = string
  sensitive   = true
}

variable "node_port" {
  description = "Internal port for Node.js backend"
  type        = number
  default     = 3050
}

variable "spring_port" {
  description = "Internal port for Spring Boot rate-limiter"
  type        = number
  default     = 3051
}
