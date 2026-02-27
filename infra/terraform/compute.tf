# Compute Engine - Application VM Instance
# e2-standard-4: 4 vCPU, 16GB RAM

# Reference existing static IP reservation "exit8-static-ip"
data "google_compute_address" "exit8_static_ip" {
  name    = "exit8-static-ip"
  project = var.project_id
  region  = var.region
}

# Service Account for the VM
resource "google_service_account" "vm_service_account" {
  account_id   = "${var.instance_name}-sa"
  display_name = "Exit8 VM Service Account"
  project      = var.project_id
}

# Grant Secret Manager accessor role
resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

# Grant Cloud SQL Client role
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

# Grant Logging and Monitoring roles
resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_project_iam_member" "metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

# Firewall Rules
resource "google_compute_firewall" "allow_health_check" {
  name    = "${var.instance_name}-allow-health-check"
  project = var.project_id
  network = google_compute_network.exit8-vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  source_ranges = [
    "35.191.0.0/16",   # Google HTTP(S) Load Balancing
    "130.211.0.0/22"   # Google HTTP(S) Load Balancing
  ]

  target_tags = [var.instance_name]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.instance_name}-allow-ssh"
  project = var.project_id
  network = google_compute_network.exit8-vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]  # Consider restricting to your IP

  target_tags = [var.instance_name]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.instance_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.exit8-vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]  # Internal traffic

  target_tags = [var.instance_name]
}

# Compute Engine Instance
resource "google_compute_instance" "exit8_vm" {
  name         = var.instance_name
  project      = var.project_id
  zone         = var.zone
  machine_type = "e2-standard-4"  # 4 vCPU, 16GB RAM

  tags = [var.instance_name, "exit8", "docker"]

  # Boot disk
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 100  # 100GB SSD
      type  = "pd-ssd"
    }
  }

  # Network interface
  network_interface {
    network    = google_compute_network.exit8-vpc.id
    subnetwork = google_compute_subnetwork.exit8-subnet.id

    access_config {
      nat_ip = data.google_compute_address.exit8_static_ip.address
    }
  }

  # Service account
  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"]
  }

  # Metadata for startup script and instance info
  metadata = {
    enable-oslogin = "FALSE"
    # Startup script will be added via Ansible
    startup-script = <<-EOF
      #!/bin/bash
      # Install Docker
      curl -fsSL https://get.docker.com -o get-docker.sh
      sh get-docker.sh
      usermod -aG docker ubuntu
      
      # Install Docker Compose
      curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose
      
      # Create app directory
      mkdir -p /opt/exit8
      chown ubuntu:ubuntu /opt/exit8
      
      # Log completion
      echo "Startup script completed at $(date)" >> /var/log/startup-script.log
    EOF
  }

  # Labels for organization
  labels = {
    environment = "demo"
    project     = "exit8"
    managed_by  = "terraform"
  }

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    google_compute_firewall.allow_health_check,
    google_compute_firewall.allow_ssh,
    google_compute_firewall.allow_internal
  ]
}

