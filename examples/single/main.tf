provider "digitalocean" {
  version = "~> 1.1" # requires that the DIGITALOCEAN_TOKEN environment variable be set
}

resource "digitalocean_ssh_key" "registry" {
  name       = "Docker Registry SSH key"
  public_key = "${file("${var.public_ssh_key_path}")}"
}

module "registry" {
  source              = "../.."
  ssh_key_fingerprint = "${digitalocean_ssh_key.registry.fingerprint}"
  admin_password      = "${var.admin_password}"
  admin_email         = "${var.admin_email}"
  fqdn                = "${var.fqdn}"
  region              = "${var.region}"
  droplet_name        = "${var.droplet_name}"
  space_name          = "${var.space_name}"
  space_key           = "${var.space_key}"
  space_secret        = "${var.space_secret}"
}

resource "null_resource" "post-check" {
  triggers = {
    registry_ip = "${module.registry.ip}"
  }

  provisioner "local-exec" {
    # Test by IP, not by FQDN, as the DNS record change may not yet be visible to your system.
    # It can take a few minutes for the necessary packages to install and for the Lets Encrypt
    # TLS certificate to be issued.
    command = "which wait-for-it && wait-for-it ${module.registry.ip}:443 -t 600"
  }
}

locals {
  ssh_command = "ssh -i ${pathexpand(replace(var.public_ssh_key_path, "/.pub$/", ""))} root@${module.registry.ip}"
}