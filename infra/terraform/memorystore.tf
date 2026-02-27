# Memorystore for Redis - Managed Redis Instance
# BASIC tier: 1GB, no replication (cost-optimized for demo)

resource "google_redis_instance" "exit8_redis" {
  name           = var.redis_name
  project        = var.project_id
  region         = var.region
  tier           = var.memorystore_tier  # BASIC
  memory_size_gb = 1

  # Network configuration - private IP via PSA
  authorized_network = google_compute_network.exit8-vpc.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  # Redis configuration
  redis_version     = "REDIS_7_0"
  display_name      = "Exit8 Redis Cache"

  # Maintenance window (Sunday 3 AM KST)
  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours   = 18  # UTC (3 AM KST = 18:00 UTC previous day)
        minutes = 0
        nanos   = 0
        seconds = 0
      }
    }
  }

  # Redis config
  redis_configs = {
    maxmemory-policy    = "allkeys-lru"  # Evict least recently used keys
    notify-keyspace-events = "Ex"         # Key expiration events
  }

  # Wait for PSA connection
  depends_on = [
    google_service_networking_connection.private_vpc_connection
  ]

  lifecycle {
    prevent_destroy = false
  }
}

