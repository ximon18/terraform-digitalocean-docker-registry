variable "region" {
  type        = "string"
  description = "The DigitalOcean region name in which to deploy a Droplet to host the Docker registry, e.g. 'ams3'."
}

variable "size" {
  type        = "string"
  description = "(optional) The DigitalOcean Droplet size to use to host the Docker registry. Defaults to a small Droplet with 1 vCPU and 1 GiB RAM."
  default     = "s-1vcpu-1gb"
}

variable "ssh_key_fingerprint" {
  type        = "string"
  description = "The fingerprint field of a digitalocean_ssh_key resource or data source that will be able to SSH into the Droplet as user 'root'."
}

variable "admin_password" {
  type        = "string"
  description = "The password to be used to authenticate as user 'admin' with the newly created Docker registry."
}

variable "admin_email" {
  type        = "string"
  description = "The email address that should receive emails from Lets Encrypt (e.g. concerning renewal, revocation or changes to the subscriber agreement). You accept the Lets Encrypt Subscriber Agreement by using this module. For more information see: https://letsencrypt.org/repository/."
}

variable "fqdn" {
  type        = "string"
  description = "A fully qualified domain name of a subdomain of a domain that you manage through DigitalOcean. A DNS A record will be created in DigitalOcean for this FQDN, pointing to the newly created Droplet which hosts the Docker registry."
}

variable "droplet_name" {
  type        = "string"
  description = "A name used to identify the Droplet to DigitalOcean. May cause a DNS PTR record to be created. For more information see: https://www.digitalocean.com/docs/networking/dns/how-to/manage-records/#ptr-rdns-records."
  default     = "docker-registry"
}

variable "space_name" {
  type        = "string"
  description = "(optional) The DigitalOcean Space in which to store Docker registry image files. Must be in the same region as the Droplet will be."
  default     = ""
}

variable "space_key" {
  type        = "string"
  description = "(required if do_space_name is non-empty) The DigitalOcean Space access key for read/write access to the Space."
  default     = ""
}

variable "space_secret" {
  type        = "string"
  description = "(required if do_space_name is non-empty) The DigitalOcean Space secret key for read/write access to the Space."
  default     = ""
}

variable "registry_http_secret" {
  type        = "string"
  description = "(optional) Only required if deploying more than one registry instance in a load-balanced setup. If not specified the Docker Registry will generate a random secret and will warn 'This may cause problems with uploads if multiple registries are behind a load-balancer'. For more information see: https://docs.docker.com/registry/deploying/#load-balancing-considerations."
  default     = ""
}
