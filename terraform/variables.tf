# File: terraform/variables.tf
# Definicje głównych zmiennych wejściowych dla całej konfiguracji Terraform.

variable "user_id" {
  description = "Unikalny identyfikator użytkownika (np. login), używany do nazewnictwa zasobów."
  type        = string
  sensitive   = true # Identyfikator użytkownika jest traktowany jako dana wrażliwa.
}

variable "admin_username" {
  description = "Nazwa użytkownika administratora tworzonego na maszynie wirtualnej."
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Hasło administratora VM. Wymagane tylko dla systemu Windows."
  type        = string
  sensitive   = true
}

variable "os_type" {
  description = "Typ systemu operacyjnego do zainstalowania na VM ('linux' lub 'windows'). Wpływa na wybór obrazu, rozmiaru VM i metody logowania."
  type        = string
  sensitive   = false
  validation {
    # Zapewnia, że podano poprawną wartość dla typu OS.
    condition     = contains(["linux", "windows"], lower(var.os_type))
    error_message = "Dozwolone wartości dla 'os_type' to 'linux' lub 'windows'."
  }
}

variable "subscription_id" {
  description = "Identyfikator subskrypcji Azure, w której będą tworzone zasoby."
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Klucz publiczny SSH używany do logowania na maszyny Linux. Wymagany, jeśli os_type='linux'."
  type        = string
  sensitive   = false # Klucze publiczne nie są zazwyczaj traktowane jako wrażliwe.
}

variable "location" {
  description = "Region Azure, w którym zostaną utworzone zasoby (np. 'West Europe', 'East US')."
  type        = string
  default     = "West Europe" # Domyślny region, jeśli nie zostanie podany.
  sensitive   = false
}

variable "image_name" {
  description = "Nazwa lub alias obrazu maszyny wirtualnej do użycia. Może to być alias obrazu z Marketplace (np. 'Ubuntu:22.04-lts-gen2') lub nazwa obrazu niestandardowego (np. 'windows10-pro')."
  type        = string
  sensitive   = false
}

variable "allowed_source_ips" {
  description = "Lista adresów IP lub zakresów CIDR, które będą miały dostęp do VM przez porty SSH/RDP/VNC zdefiniowane w NSG."
  type        = list(string)
  # UWAGA: Domyślnie zezwala na dostęp z dowolnego adresu IP. W środowiskach produkcyjnych należy to ograniczyć.
  default   = ["0.0.0.0/0"]
  sensitive = false
}

variable "linux_vm_size" {
  description = "Rozmiar maszyny wirtualnej Azure używany dla systemu Linux."
  type        = string
  default     = "Standard_B1s" # Domyślny, ekonomiczny rozmiar dla Linux.
  sensitive   = false
}

variable "windows_vm_size" {
  description = "Rozmiar maszyny wirtualnej Azure używany dla systemu Windows."
  type        = string
  default     = "Standard_D2s_v3" # Domyślny rozmiar dla Windows, zazwyczaj wymaga więcej zasobów.
  sensitive   = false
}

variable "custom_image_rg_name" {
  description = "Nazwa grupy zasobów Azure, która zawiera niestandardowe obrazy maszyn wirtualnych."
  type        = string
  default     = "packer-images-rg" # Domyślna nazwa RG dla obrazów stworzonych np. przez Packer.
  sensitive   = false
}

variable "destroy_timestamp_utc" {
  description = "Opcjonalny znacznik czasu w formacie UTC (ISO 8601, np. YYYY-MM-DDTHH:MM:SSZ), wskazujący kiedy VM powinna zostać automatycznie zniszczona przez zewnętrzny proces czyszczący. Pozostaw pusty, aby wyłączyć."
  type        = string
  default     = "" # Domyślnie brak automatycznego niszczenia.
  sensitive   = false
}
