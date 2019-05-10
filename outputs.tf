output "ip" {
  value       = "${digitalocean_droplet.registry.ipv4_address}"
  description = "The IPv4 address of the newly deployed DigitalOcean droplet that hosts your Docker registry."
}

output "fqdn" {
  value       = "${digitalocean_record.registry.fqdn}"
  description = "The fully qualified domain name that points to the IP address of your new Docker registry."
}