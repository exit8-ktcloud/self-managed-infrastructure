# GCP Project ID
variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must match Google Cloud project ID format (lowercase, 6-30 characters, letters, numbers, hyphens)."
  }
}

# GCP Region
variable "region" {
  description = "The Google Cloud region for resources"
  type        = string
  default     = "asia-northeast3"  # Seoul
}

# GCP Zone
variable "zone" {
  description = "The Google Cloud zone for zonal resources"
  type        = string
  default     = "asia-northeast3-a"  # Seoul Zone A
}

# VM Instance Name
variable "instance_name" {
  description = "Name of the VM instance"
  type        = string
  default     = "exit8-vm"
}

# PostgreSQL Database Name
variable "db_name" {
  description = "PostgreSQL DB Name"
  type        = string
  default     = "exit8-postgres"
}

# Redis Name
variable "redis_name" {
  description = "Redis Name"
  type        = string
  default     = "exit8-redis"
}

# Load Balancer Name
variable "lb_name" {
  description = "Load Balancer Name"
  type        = string
  default     = "exit8-lb"
}

# Cloud SQL Instance Tier
variable "db_tier" {
  description = "Cloud SQL Tier (db-custom-2-8192)"
  type        = string
  default     = "db-custom-2-8192"
}

# Memorystore for Redis Tier
variable "memorystore_tier" {
  description = "Memorystore Tier (BASIC)"
  type        = string
  default     = "BASIC"
}

# Cloud SQL Storage Size (GB)
variable "db_size" {
  description = "Cloud SQL Storage (GB)"
  type        = number
  default     = 10
}

# Cloud SQL vCPU Count
variable "db_cpu" {
  description = "Cloud SQL vCPU"
  type        = number
  default     = 2
}

# Cloud SQL RAM (GB)
variable "db_ram" {
  description = "Cloud SQL RAM (GB)"
  type        = number
  default     = 8
}
