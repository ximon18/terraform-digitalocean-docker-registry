output "registry.ip" {
  value = "${module.registry.ip}"
}

output "registry.fqdn" {
  value = "${module.registry.fqdn}"
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