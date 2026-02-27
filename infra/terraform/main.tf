# Terraform Block - Provider Version Constraints
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Backend configuration can be added later
  # backend "gcs" {
  #   bucket  = "terraform-state-bucket"
  #   prefix  = "terraform/state"
  # }
}

# Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  # Authentication via ADC (Application Default Credentials)
  # Run: gcloud auth application-default login
  # Or set GOOGLE_APPLICATION_CREDENTIALS environment variable
}
