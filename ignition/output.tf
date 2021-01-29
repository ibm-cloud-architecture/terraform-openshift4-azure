output "bootstrap_ignition" {
  value = data.ignition_config.bootstrap_redirect.rendered
}

output "master_ignition" {
  value = data.ignition_config.master_redirect.rendered
}
