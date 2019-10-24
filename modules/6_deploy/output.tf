output "module_completed" {
  value = join(",",
    list(null_resource.install-cluster.id),
    azurerm_image.rhcosimage.*.id,
  )
}
