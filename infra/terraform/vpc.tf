# Google Compute VPC Network
resource "google_compute_network" "exit8-vpc" {
  name                    = "exit8-vpc"
  auto_create_subnetworks = false  # Manual subnet management
  routing_mode            = "REGIONAL"

  lifecycle {
    create_before_destroy = true
  }
}
