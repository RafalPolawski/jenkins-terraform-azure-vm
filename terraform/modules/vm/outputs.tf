# File: terraform/modules/vm/outputs.tf
# Wartości wyjściowe modułu VM.

output "vm_name" {
  description = "Nazwa utworzonej maszyny wirtualnej (Linux lub Windows)."
  # Zwraca nazwę odpowiedniego zasobu VM w zależności od `var.os_type`.
  value = lower(var.os_type) == "linux" ? azurerm_linux_virtual_machine.linux_vm[0].name : azurerm_windows_virtual_machine.windows_vm[0].name
}
