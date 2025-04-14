# File: terraform/modules/vm/variables.tf
# Zmienne wejściowe dla modułu tworzącego maszynę wirtualną (VM).

variable "os_type" {
  description = "Typ systemu operacyjnego ('linux' lub 'windows'). Determinuje, który zasób VM (Linux/Windows) zostanie utworzony."
  type        = string
}

variable "image_name" {
  description = "Nazwa lub alias obrazu VM do użycia (z Marketplace lub niestandardowy)."
  type        = string
}

variable "user_id" {
  description = "Unikalny identyfikator użytkownika, używany w nazewnictwie VM."
  type        = string
  sensitive   = true
}

variable "admin_username" {
  description = "Nazwa użytkownika administratora na tworzonej VM."
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Hasło administratora VM. Wymagane i używane tylko dla systemu Windows."
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Klucz publiczny SSH. Wymagany i używany tylko do logowania na maszyny Linux."
  type        = string
  sensitive   = false # Klucze publiczne nie są zazwyczaj traktowane jako wrażliwe.
}

variable "resource_group_name" {
  description = "Nazwa grupy zasobów Azure, w której zostanie utworzona VM."
  type        = string
}

variable "location" {
  description = "Region Azure, w którym zostanie utworzona VM."
  type        = string
}

variable "network_interface_id" {
  description = "ID interfejsu sieciowego (NIC), który zostanie przypisany do VM."
  type        = string
}

variable "subscription_id" {
  description = "Identyfikator subskrypcji Azure. Potrzebny do konstruowania ID obrazów niestandardowych."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Mapa tagów do zastosowania dla zasobów VM."
  type        = map(string)
  default     = {}
}

variable "vm_size" {
  description = "Rozmiar (typ) maszyny wirtualnej Azure (np. 'Standard_B1s', 'Standard_D2s_v3')."
  type        = string
}

variable "custom_image_rg_name" {
  description = "Nazwa grupy zasobów Azure zawierającej obrazy niestandardowe."
  type        = string
}

variable "destroy_timestamp_utc" {
  description = "Opcjonalny znacznik czasu UTC (ISO 8601), kiedy VM powinna zostać zniszczona przez zewnętrzny proces. Używany do dodania tagu 'DestroyTimestampUTC'."
  type        = string
  default     = ""
  sensitive   = false
}
