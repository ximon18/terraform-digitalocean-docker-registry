# See the README.md that comes with this template.

# Settings related to the location of the new private Docker registry:
# --------------------------------------------------------------------
# The fully qualfied domain name that the registry should be reachable at. MUST be a subdomain of the domain you
# configured in Digital Ocean. Lets Encrypt will be used to obtain and automatically renew a TLS certificate for this
# domain.
variable "fqdn" {}
# The Digital Ocean region in which to deploy the registry Droplet, e.g. "ams3"
variable "do_region" {}
# The name of the Digital Ocean Droplet that will be created to host the private Docker registry.
variable "do_droplet_name" {
  default = "private-docker-registry"
}

# Settings related to access control:
# --------------------------------------------------------------------
# A pre-existing SSH public key file, e.g. created with ssh-keygen.
variable "public_ssh_key_path" {
  default = "~/.ssh/id_rsa.pub"
}
# The email address of the owner of the FQDN. Used by Lets Encrypt.
variable "admin_email" {}
# The password for the 'admin' user that will be granted access to the new registry.
variable "admin_password" {}

# Settings related to Digital Ocean Spaces:
# -----------------------------------------
# (optional) The name of a Digital Ocean space where Docker registry images will be stored. If empty, images will be
# stored in the registry Docker container and will be lost when the container or Digital Ocean Droplet are lost.
variable "do_space_name" {
  default = ""
}
# (required if do_space_name is non-empty) The Digital Ocean Space access key (see API -> Tokens/Keys in the DO UI).
variable "do_space_key" {
  default = ""
}
# (required if do_space_name is non-empty) The Digital Ocean Space secret key (see API -> Tokens/Keys in the DO UI).
variable "do_space_secret" {
  default = ""
}

provider "digitalocean" { # requires that the DIGITALOCEAN_TOKEN environment variable be set
  version = "~> 1.1"
}

resource "digitalocean_ssh_key" "registry" {
  name       = "Docker Registry SSH key"
  public_key = "${file("${var.public_ssh_key_path}")}"
}

module "registry" {
  source              = "do_private_docker_registry"
  ssh_key_fingerprint = "${digitalocean_ssh_key.registry.fingerprint}"
  admin_password      = "${var.admin_password}"
  admin_email         = "${var.admin_email}"
  fqdn                = "${var.fqdn}"
  do_region           = "${var.do_region}"
  do_droplet_name     = "${var.do_droplet_name}"
  do_space_name       = "${var.do_space_name}"
  do_space_key        = "${var.do_space_key}"
  do_space_secret     = "${var.do_space_secret}"
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


output "registry.ip" {
  value = "${module.registry.ip}"
}
output "registry.fqdn" {
  value = "${module.registry.fqdn}"
}
output "registry.catalog_url" {
  value = "${module.registry.catalog_url}"
}
output "command.ssh" {
  value = "${local.ssh_command}"
}

output "command.check_deployment_log" {
  value = "${local.ssh_command} tail /var/log/cloud-init-output.log"
}

output "command.check_registry_log" {
  value = "${local.ssh_command} docker logs registry"
}