# Additional Secrets for Exit8 Infrastructure
# Stores non-database secrets in GCP Secret Manager

# ============================================================================
# Grafana Admin Credentials
# ============================================================================

resource "random_password" "grafana_password" {
  length  = 24
  special = false  # Avoid special chars for simpler handling
}

resource "google_secret_manager_secret" "grafana_admin" {
  secret_id = "exit8-grafana-admin"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "grafana_admin_version" {
  secret      = google_secret_manager_secret.grafana_admin.id
  secret_data = jsonencode({
    admin_user     = "admin"
    admin_password = random_password.grafana_password.result
  })
}

# ============================================================================
# Wazuh SIEM Credentials
# ============================================================================

resource "random_password" "wazuh_indexer_password" {
  length  = 24
  special = false
}

resource "random_password" "wazuh_api_password" {
  length  = 24
  special = false
}

resource "random_password" "wazuh_dashboard_password" {
  length  = 24
  special = false
}

resource "google_secret_manager_secret" "wazuh_credentials" {
  secret_id = "exit8-wazuh-credentials"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "wazuh_credentials_version" {
  secret      = google_secret_manager_secret.wazuh_credentials.id
  secret_data = jsonencode({
    indexer_password  = random_password.wazuh_indexer_password.result
    api_password      = random_password.wazuh_api_password.result
    dashboard_password = random_password.wazuh_dashboard_password.result
  })
}

# ============================================================================
# Outputs
# ============================================================================

output "grafana_admin_secret_id" {
  value       = google_secret_manager_secret_version.grafana_admin_version.id
  description = "Secret Manager ID for Grafana admin credentials"
}

output "wazuh_credentials_secret_id" {
  value       = google_secret_manager_secret_version.wazuh_credentials_version.id
  description = "Secret Manager ID for Wazuh credentials"
}
