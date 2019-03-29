terraform {
  required_version = "~> 0.11.13"
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
    REGISTRY_S3_ACCESSKEY = "${var.space_key}"
    REGISTRY_S3_SECRETKEY = "${var.space_secret}"
    REGISTRY_S3_BUCKET    = "${var.space_name}"
    REGISTRY_S3_REGION    = "${var.region}"
    REGISTRY_S3_ENDPOINT  = "${var.space_name == "" ? "" : "https://${var.region}.digitaloceanspaces.com"}"

    REGISTRY_HTTP_SECRET = "${var.registry_http_secret}"
  }
}

resource "digitalocean_droplet" "registry" {
  name     = "${var.droplet_name}"
  image    = "${data.digitalocean_image.docker.image}"
  region   = "${var.region}"
  size     = "${var.size}"
  ssh_keys = ["${var.ssh_key_fingerprint}"]

  # execute `cat /var/log/cloud-init-output.log` on the droplet to diagnose problems with execution of user_data commands
  # execute `cat /var/lib/cloud/instance/scripts/part-001` on the droplet to see the script after interpolation
  # execute 'docker logs registry' to see the error log of the Docker registry application.
  user_data = "${data.template_file.registry_init.rendered}"
}
