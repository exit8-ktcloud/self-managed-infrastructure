# Consolidated Outputs for Exit8 Infrastructure

# ============================================================================
# Network Outputs
# ============================================================================

output "vpc_network_name" {
  value       = google_compute_network.exit8-vpc.name
  description = "VPC network name"
}

output "subnet_name" {
  value       = google_compute_subnetwork.exit8-subnet.name
  description = "Subnet name"
}

output "subnet_cidr" {
  value       = google_compute_subnetwork.exit8-subnet.ip_cidr_range
  description = "Subnet CIDR range"
}

# ============================================================================
# Database Outputs (Cloud SQL)
# ============================================================================

output "cloud_sql_connection_name" {
  value       = google_sql_database_instance.exit8_postgres.connection_name
  description = "Cloud SQL connection name for Cloud SQL Proxy"
}

output "cloud_sql_private_ip" {
  value       = google_sql_database_instance.exit8_postgres.private_ip_address
  description = "Cloud SQL private IP address (accessible from VPC)"
}

output "cloud_sql_database_name" {
  value       = google_sql_database.app_database.name
  description = "Application database name"
}

output "cloud_sql_user_name" {
  value       = google_sql_user.app_user.name
  description = "Application database user"
}

output "cloud_sql_password_secret_id" {
  value       = google_secret_manager_secret_version.db_password_version.id
  description = "Secret Manager ID for database password"
}

# ============================================================================
# Cache Outputs (Memorystore Redis)
# ============================================================================

output "redis_host" {
  value       = google_redis_instance.exit8_redis.host
  description = "Redis instance host (private IP)"
}

output "redis_port" {
  value       = google_redis_instance.exit8_redis.port
  description = "Redis instance port"
}

output "redis_connection_string" {
  value       = "${google_redis_instance.exit8_redis.host}:${google_redis_instance.exit8_redis.port}"
  description = "Redis connection string"
}

# ============================================================================
# Compute Outputs
# ============================================================================

output "vm_instance_name" {
  value       = google_compute_instance.exit8_vm.name
  description = "VM instance name"
}

output "vm_external_ip" {
  value       = data.google_compute_address.exit8_static_ip.address
  description = "VM external (public) IP address"
}

output "vm_internal_ip" {
  value       = google_compute_instance.exit8_vm.network_interface[0].network_ip
  description = "VM internal IP address"
}

output "vm_service_account_email" {
  value       = google_service_account.vm_service_account.email
  description = "Service account email for the VM"
}

output "ssh_command" {
  value       = "gcloud compute ssh ${var.instance_name} --zone=${var.zone} --project=${var.project_id}"
  description = "Command to SSH into the VM"
}

# ============================================================================
# Load Balancer Outputs
# ============================================================================

output "lb_ip_address" {
  value       = google_compute_global_address.lb_ip.address
  description = "Load Balancer public IP address"
}

output "lb_https_url" {
  value       = "https://${google_compute_global_address.lb_ip.address}"
  description = "HTTPS URL to access the application"
}

output "ssl_certificate_domains" {
  value       = google_compute_managed_ssl_certificate.exit8_cert.managed[*].domains
  description = "Domains covered by SSL certificate"
}

# ============================================================================
# Monitoring Outputs
# ============================================================================

output "monitoring_dashboard_url" {
  value       = "https://console.cloud.google.com/monitoring/dashboards?project=${var.project_id}"
  description = "URL to Cloud Monitoring dashboards"
}

output "alert_policy_names" {
  value = {
    high_cpu            = google_monitoring_alert_policy.high_cpu.display_name
    high_db_connections = google_monitoring_alert_policy.high_db_connections.display_name
    high_redis_memory   = google_monitoring_alert_policy.high_redis_memory.display_name
    lb_5xx_errors       = google_monitoring_alert_policy.lb_5xx_errors.display_name
  }
  description = "Alert policies created"
}

# ============================================================================
# Application Connection Summary
# ============================================================================

output "application_env_vars" {
  value = {
    DATABASE_URL     = "jdbc:postgresql://${google_sql_database_instance.exit8_postgres.private_ip_address}:5432/${google_sql_database.app_database.name}?ssl=true"
    DATABASE_USER    = google_sql_user.app_user.name
    DATABASE_HOST    = google_sql_database_instance.exit8_postgres.private_ip_address
    DATABASE_PORT    = "5432"
    DATABASE_NAME    = google_sql_database.app_database.name
    REDIS_HOST       = google_redis_instance.exit8_redis.host
    REDIS_PORT       = tostring(google_redis_instance.exit8_redis.port)
    REDIS_URL        = "redis://${google_redis_instance.exit8_redis.host}:${google_redis_instance.exit8_redis.port}"
  }
  description = "Environment variables for application configuration"
  sensitive   = true
}

# ============================================================================
# Cost Estimation Helper
# ============================================================================

output "estimated_monthly_cost" {
  value = {
    cloud_sql = "~$50/month (db-custom-2-8192 + 10GB SSD)"
    redis     = "~$35/month (1GB Basic)"
    vm        = "~$70/month (e2-standard-4 + 100GB SSD)"
    lb        = "~$20/month (HTTPS LB + Cloud Armor)"
    total     = "~$175/month (~₩250,000)"
  }
  description = "Estimated monthly cost breakdown"
}
