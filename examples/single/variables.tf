# Settings related to the location of the new private Docker registry:
# --------------------------------------------------------------------
# The fully qualfied domain name that the registry should be reachable at. MUST be a subdomain of the domain you
# configured in Digital Ocean. Lets Encrypt will be used to obtain and automatically renew a TLS certificate for this
# domain.
variable "fqdn" {}

# The Digital Ocean region in which to deploy the registry Droplet, e.g. "ams3"
variable "region" {}

# The name of the Digital Ocean Droplet that will be created to host the private Docker registry.
variable "droplet_name" {
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
variable "space_name" {
  default = ""
}

# (required if do_space_name is non-empty) The Digital Ocean Space access key (see API -> Tokens/Keys in the DO UI).
variable "space_key" {
  default = ""
}

# (required if do_space_name is non-empty) The Digital Ocean Space secret key (see API -> Tokens/Keys in the DO UI).
variable "space_secret" {
  default = ""
}
