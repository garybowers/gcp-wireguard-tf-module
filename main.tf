data "google_compute_zones" "random_zone" {
  count   = length(var.servers)
  project = var.project_id
  region  = var.servers[count.index]["subnetwork"].region
}

resource "random_shuffle" "zone" {
  count        = length(var.servers)
  input        = data.google_compute_zones.random_zone[count.index].names
  result_count = 1
}

resource "random_id" "wg-postfix" {
  byte_length = 4
}

resource "google_service_account" "wireguard-svc-account" {
  count        = length(var.servers)
  project      = var.project_id
  account_id   = "${var.prefix}-${var.servers[count.index]["name"]}-svc-${random_id.wg-postfix.hex}"
  display_name = "${var.prefix}-${var.servers[count.index]["name"]}-svc-${random_id.wg-postfix.hex}"
}

resource "google_storage_bucket_access_control" "wireguard-config-acl" {
  count  = length(var.servers)
  bucket = var.config_bucket.name
  role   = "WRITER"
  entity = "user-${google_service_account.wireguard-svc-account[count.index].email}"
}

resource "google_storage_bucket_object" "wireguard" {
  count   = length(var.servers)
  name    = "${var.servers[count.index]["name"]}/"
  content = "NA"
  bucket  = var.config_bucket.name
}

resource "google_storage_bucket_object" "wg0conf" {
  count  = length(var.servers)
  name   = "${var.servers[count.index]["name"]}/wg0.conf"
  source = var.servers[count.index]["config_file"]
  bucket = var.config_bucket.name
}

resource "google_storage_bucket_iam_member" "members" {
  count  = length(var.servers)
  bucket = var.config_bucket.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.wireguard-svc-account[count.index].email}"
}

resource "google_project_iam_member" "wireguard-svc-iam-logwriter" {
  count   = length(var.servers)
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.wireguard-svc-account[count.index].email}"
}

resource "google_compute_address" "external-address" {
  count   = length(var.servers)
  name    = "${var.prefix}-${var.servers[count.index]["name"]}-${random_id.wg-postfix.hex}"
  project = var.project_id

  region       = var.servers[count.index]["subnetwork"].region
  address_type = "EXTERNAL"
}

resource "google_compute_firewall" "ingress-allow-wireguard" {
  count   = length(var.servers)
  project = var.project_id
  name    = "${var.prefix}-ingress-allow-${var.servers[count.index]["name"]}-${random_id.wg-postfix.hex}"
  network = var.vpc_network

  priority = 200

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  source_ranges           = ["0.0.0.0/0"]
  target_service_accounts = [google_service_account.wireguard-svc-account[count.index].email]
}

resource "google_compute_instance_template" "wireguard-tpl" {
  count       = length(var.servers)
  project     = var.project_id
  name_prefix = "${var.prefix}-${var.servers[count.index]["name"]}-tpl-"
  description = "Wireguard Server Template"

  instance_description = "Wireguard Server"
  machine_type         = var.servers[count.index]["machine_type"]

  can_ip_forward = true

  tags = ["${var.prefix}-ingress-allow-wireguard-${random_id.wg-postfix.hex}"]

  disk {
    auto_delete = true
    boot        = true

    source_image = "debian-cloud/debian-10"
    disk_type    = var.servers[count.index]["disk_type"]
    disk_size_gb = var.servers[count.index]["disk_size"]
  }

  network_interface {
    network    = var.vpc_network
    subnetwork = var.servers[count.index]["subnetwork"].self_link
    access_config {
      nat_ip = google_compute_address.external-address[count.index].address
    }
  }

  service_account {
    email  = google_service_account.wireguard-svc-account[count.index].email
    scopes = ["storage-ro", "cloud-platform"]
  }

  metadata_startup_script = <<EOF
export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s`
echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
apt-get update -y
apt-get install -y wireguard wireguard-tools nfs-common iptables linux-headers-$(uname -r) resolvconf gcsfuse 
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -w net.ipv6.conf.all.forwarding=1
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
gcsfuse --only-dir ${var.servers[count.index]["name"]} --file-mode 600 ${var.config_bucket.name} /etc/wireguard/
wg-quick up wg0
sysctl enable wg-quick@wg0
sysctl start wg-quick@wg0
EOF

  lifecycle {
    create_before_destroy = true
  }

}


resource "google_compute_instance_group_manager" "wireguard-mig" {
  count   = length(var.servers)
  project = var.project_id
  name    = "${var.prefix}-${var.servers[count.index]["name"]}-mig"
  zone    = random_shuffle.zone[count.index].result[0]

  base_instance_name = "${var.prefix}-${var.servers[count.index]["name"]}"
  wait_for_instances = true

  target_size = 1

  version {
    instance_template = google_compute_instance_template.wireguard-tpl[count.index].id
  }

  update_policy {
    max_surge_fixed = 1
    type            = "PROACTIVE"
    minimal_action  = "REPLACE"
  }

}
