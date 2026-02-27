# Cloud SQL - PostgreSQL Managed Database
# db-custom-2-8192: 2 vCPU, 8GB RAM

# Generate random password for PostgreSQL
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store password in Secret Manager
resource "google_secret_manager_secret" "db_password_secret" {
  secret_id = "exit8-db-password"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password_secret.id
  secret_data = random_password.db_password.result
}

# Cloud SQL Instance
resource "google_sql_database_instance" "exit8_postgres" {
  name             = var.db_name
  project          = var.project_id
  region           = var.region
  database_version = "POSTGRES_15"

  settings {
    tier              = var.db_tier  # db-custom-2-8192
    availability_type = "ZONAL"      # Single zone for cost (vs REGIONAL)
    disk_type         = "PD_SSD"
    disk_size         = var.db_size  # 10GB
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false  # Disable public IP
      private_network = google_compute_network.exit8-vpc.id
      ssl_mode = "ENCRYPTED_ONLY"
    }

    database_flags {
      name  = "max_connections"
      value = "200"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"  # 2 AM KST
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 3
    }

    maintenance_window {
      day          = 7  # Sunday
      hour         = 3  # 3 AM
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }
  }

  # Wait for PSA connection to be established
  depends_on = [
    google_service_networking_connection.private_vpc_connection
  ]

  deletion_protection = false  # Set to true for production

  lifecycle {
    prevent_destroy = false
  }
}

# Application Database
resource "google_sql_database" "app_database" {
  name     = "exit8_app"
  project  = var.project_id
  instance = google_sql_database_instance.exit8_postgres.name
}

# Application User
resource "google_sql_user" "app_user" {
  name     = "exit8_app_user"
  project  = var.project_id
  instance = google_sql_database_instance.exit8_postgres.name
  password = random_password.db_password.result
}

