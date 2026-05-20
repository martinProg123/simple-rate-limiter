variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-east-1"
}

variable "rate_limiter_max_tokens" {
  description = "Max tokens for rate limiter"
  type        = number
  default     = 50
}

variable "rate_limiter_refill_rate" {
  description = "Refill rate for rate limiter (tokens per second)"
  type        = number
  default     = 10
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "ghcr_user" {
  description = "GitHub Container Registry username"
  type        = string
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
