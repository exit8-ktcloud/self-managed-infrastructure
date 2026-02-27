# Private Service Access (PSA) Configuration for Exit8
# Enables private IP access to Google Cloud managed services

# Reserve IP range for PSA
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "exit8-psa"
  project       = var.project_id
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = 16
  network       = google_compute_network.exit8-vpc.id
}

# Establish PSA connection to Google services
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.exit8-vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]

  # 1-2 day TTL (172800 seconds)
  deletion_policy = "ABANDON"

  depends_on = [
    google_compute_global_address.private_ip_alloc
  ]
}

# Create router for NAT
resource "google_compute_router" "exit8-router" {
  name    = "exit8-router"
  network = google_compute_network.exit8-vpc.id
  region  = var.region
}

# Allow NAT for PSA services
resource "google_compute_router_nat" "psa_nat" {
  name   = "exit8-psa-nat"
  router = google_compute_router.exit8-router.name
  region = var.region

  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
  nat_ip_allocate_option             = "AUTO_ONLY"

  log_config {
    enable = true
    filter = "ALL"
  }
}
