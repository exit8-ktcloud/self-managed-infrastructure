# Subnet Resource - Private Subnet for PSA (Private Service Access)
resource "google_compute_subnetwork" "exit8-subnet" {
  name                     = "exit8-subnet"
  ip_cidr_range            = "10.0.0.0/24"
  region                   = var.region
  network                  = google_compute_network.exit8-vpc.id

  # Disable automatic subnet creation (depends on PSA configuration)
  # Private Service Access (PSA) requires manual configuration
  private_ip_google_access = false

  lifecycle {
    # Prevent accidental recreation
    prevent_destroy = false
  }
}
