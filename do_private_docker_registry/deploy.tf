terraform {
  required_version = "~> 0.11.13"
}
variable "do_region" {
  type = "string"
  description = "The Digital Ocean region name in which to deploy a Droplet to host the Docker registry, e.g. 'ams3'."
}
variable "do_size" {
  type = "string"
  description = "(optional) The Digital Ocean Droplet size to use to host the Docker registry. Defaults to a small Droplet with 1 vCPU and 1 GiB RAM."
  default = "s-1vcpu-1gb"
}
variable "ssh_key_fingerprint" {
  type = "string"
  description = "The fingerprint field of a digitalocean_ssh_key resource or data source that will be able to SSH into the Droplet as user 'root'."
}
variable "admin_password" {
  type = "string"
  description = "The password to be used to authenticate as user 'admin' with the newly created Docker registry."
}
variable "admin_email" {
  type = "string"
  description = "The email address that should receive emails from Lets Encrypt (e.g. concerning renewal, revocation or changes to the subscriber agreement). You accept the Lets Encrypt Subscriber Agreement by using this module. For more information see: https://letsencrypt.org/repository/."
}
variable "fqdn" {
  type = "string"
  description = "A fully qualified domain name of a subdomain of a domain that you manage through Digital Ocean. A DNS A record will be created in Digital Ocean for this FQDN, pointing to the newly created Droplet which hosts the Docker registry."
}
variable "do_droplet_name" {
  type = "string"
  description = "A name used to identify the Droplet to Digital Ocean. May cause a DNS PTR record to be created. For more information see: https://www.digitalocean.com/docs/networking/dns/how-to/manage-records/#ptr-rdns-records."
}
variable "do_space_name" {
  type = "string"
  description = "(optional) The Digital Ocean Space in which to store Docker registry image files. Must be in the same region as the Droplet will be."
  default = ""
}
variable "do_space_key" {
  type = "string"
  description = "(required if do_space_name is non-empty) The Digital Ocean Space access key for read/write access to the Space."
  default = ""
}
variable "do_space_secret" {
  type = "string"
  description = "(required if do_space_name is non-empty) The Digital Ocean Space secret key for read/write access to the Space."
  default = ""
}
variable "registry_http_secret" {
  type = "string"
  description = "(optional) Only required if deploying more than one registry instance in a load-balanced setup. If not specified the Docker Registry will generate a random secret and will warn 'This may cause problems with uploads if multiple registries are behind a load-balancer'. For more information see: https://docs.docker.com/registry/deploying/#load-balancing-considerations."
  default = ""
}

data "digitalocean_image" "docker" {
  slug = "docker-18-04"
}

locals {
  fqdn_elements = "${split(".", var.fqdn)}"
}

resource "digitalocean_record" "registry" {
  name   = "${local.fqdn_elements[0]}"
  domain = "${join(".", slice(local.fqdn_elements, 1, length(local.fqdn_elements)))}"
  type   = "A"
  value  = "${digitalocean_droplet.registry.ipv4_address}"
}

data "template_file" "registry_init" {
  template = "${file("${path.module}/registry-init.sh")}"

  vars = {
    REGISTRY_ADMIN_PASSWORD = "${var.admin_password}"
    REGISTRY_ADMIN_EMAIL    = "${var.admin_email}"
    REGISTRY_FQDN           = "${var.fqdn}"

    # REGISTRY_S3_xxx variables are only used if REGISTRY_S3_ENDPOINT is non-empty 
    # See: https://developers.digitalocean.com/documentation/spaces/
    # See: https://www.digitalocean.com/community/questions/docker-registry-with-spaces-as-storage
    REGISTRY_S3_CHECK_HEALTH = "false"

    REGISTRY_S3_ENCRYPT   = "false"
    REGISTRY_S3_ENCRYPT   = "false"
    REGISTRY_S3_ACCESSKEY = "${var.do_space_key}"
    REGISTRY_S3_SECRETKEY = "${var.do_space_secret}"
    REGISTRY_S3_BUCKET    = "${var.do_space_name}"
    REGISTRY_S3_REGION    = "${var.do_region}"
    REGISTRY_S3_ENDPOINT  = "${var.do_space_name == "" ? "" : "https://${var.do_region}.digitaloceanspaces.com"}"

    REGISTRY_HTTP_SECRET  = "${var.registry_http_secret}"
  }
}

resource "digitalocean_droplet" "registry" {
  name     = "${var.do_droplet_name}"
  image    = "${data.digitalocean_image.docker.image}"
  region   = "${var.do_region}"
  size     = "${var.do_size}"
  ssh_keys = ["${var.ssh_key_fingerprint}"]

  # execute `cat /var/log/cloud-init-output.log` on the droplet to diagnose problems with execution of user_data commands
  # execute `cat /var/lib/cloud/instance/scripts/part-001` on the droplet to see the script after interpolation
  # execute 'docker logs registry' to see the error log of the Docker registry application.
  user_data = "${data.template_file.registry_init.rendered}"
}

output "ip" {
  value = "${digitalocean_droplet.registry.ipv4_address}"
}
output "fqdn" {
  value = "${digitalocean_record.registry.fqdn}"
}
output "catalog_url" {
  value = "https://${digitalocean_record.registry.fqdn}/v2/_catalog"
}
