// PROVIDER
provider "google" {
  project = "amr-1-377214"
  region  = "us-east1"
  zone    = "us-east1-b"
}

// CREATE VPC
resource "google_compute_network" "demo-vpc" {
  name                    = "demo-vpc"
  auto_create_subnetworks = false
}

// CREATE FIREWALL TO ALLOW SSH AND HTTP(S)
resource "google_compute_firewall" "ssh-firewall" {
  name          = "allow-ssh"
  network       = google_compute_network.demo-vpc.id
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }
}

// CREATE MANAGEMENT SUBNET
resource "google_compute_subnetwork" "management-subnet" {
  name                     = "management-subnet"
  region                   = "us-east1"
  ip_cidr_range            = "10.10.0.0/16"
  network                  = google_compute_network.demo-vpc.id
  private_ip_google_access = true
}

// CREATE RESTRICTED SUBNET
resource "google_compute_subnetwork" "restricted-subnet" {
  name                     = "restricted-subnet"
  region                   = "us-east1"
  ip_cidr_range            = "10.11.0.0/16"
  network                  = google_compute_network.demo-vpc.id
  private_ip_google_access = true
}

// CREATE MANAGEMENT ROUTER
resource "google_compute_router" "management-router" {
  name    = "management-router-nat"
  network = google_compute_network.demo-vpc.name
  region  = "us-east1"
}

// CREATE MANAGEMENT NAT GATEWAY
resource "google_compute_router_nat" "management-router-nat" {
  name                               = "management-router-nat"
  router                             = google_compute_router.management-router.name
  region                             = google_compute_router.management-router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

// CREATE VM SERVICE ACCOUNT
resource "google_service_account" "vm-service-account" {
  account_id   = "vm-service-account"
  display_name = "VM service account"
}

// CREATE VM ROLE
resource "google_project_iam_member" "vm-sa-role" {
  project = "amr-1-377214"
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.vm-service-account.email}"
}

// CREATE VM INSTANCE
resource "google_compute_instance" "management-vm" {
  name         = "management-vm"
  machine_type = "e2-medium"
  zone         = "us-east1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.demo-vpc.id
    subnetwork = google_compute_subnetwork.management-subnet.id

    access_config {
      // To make the it puplic
    }
  }

  service_account {
    email = google_service_account.vm-service-account.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  metadata_startup_script = file("script.sh")

  metadata = {
    Name = "Management VM"
  }
}

//CREATE GKE SERVICE ACCOUNT
resource "google_service_account" "gke-service-account" {
  account_id   = "gke-service-account"
  display_name = "GKE service account"
}

// CREATE GKE ROLE
resource "google_project_iam_member" "gke-sa-role" {
  project = "amr-1-377214"
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.gke-service-account.email}"
}

//CREATE PRIVATE GKE
resource "google_container_cluster" "private-gke" {
  name                     = "private-gke"
  location                 = "us-east1-b"
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = google_compute_network.demo-vpc.id
  subnetwork               = google_compute_subnetwork.restricted-subnet.id

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.101.0.0/16"
    services_ipv4_cidr_block = "10.102.0.0/16"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = google_compute_subnetwork.management-subnet.ip_cidr_range
      display_name = "External control plan access by management subnet"
    }
  }

  private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes    = true
    master_ipv4_cidr_block  = "10.100.100.0/28"
  }
}

// CREATE NODE POOL
resource "google_container_node_pool" "private-gke-node-pool" {
  name              = "private-gke-node-pool"
  location          = google_container_cluster.private-gke.location
  node_locations    = ["us-east1-b"]
  cluster           = google_container_cluster.private-gke.id
  node_count        = 1
  max_pods_per_node = 110

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  # autoscaling {
  #   min_node_count = 1
  #   max_node_count = 3
  # }

  node_config {
    preemptible  = true
    machine_type = "e2-medium"
    disk_size_gb = 100
    disk_type    = "pd-balanced"
    image_type   = "COS_CONTAINERD"

    service_account = google_service_account.gke-service-account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}
