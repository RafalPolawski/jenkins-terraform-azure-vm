# File: /terraform/variables.tf
# Definicja zmiennych wejściowych dla całej konfiguracji

# Unikalny identyfikator użytkownika
variable "user_id" {
  description = "Unikalny identyfikator użytkownika (wymagany dla nazewnictwa i tagów)"
  type        = string
}

# Dane dostępowe administratora
variable "admin_username" {
  description = "Nazwa użytkownika z uprawnieniami administratorskimi"
  type        = string
  default     = "studentadmin"  # Wartość domyślna dla szkoleń
}

variable "admin_password" {
  description = "Hasło administratora"
  type        = string
  sensitive   = true  # Oznaczenie jako wrażliwe
  default     = "StudentPassword123!"  # Tylko dla środowisk testowych!
}

# Wybór systemu operacyjnego z walidacją wartości
variable "os_type" {
  description = "Wybór między 'linux' a 'windows' (case-insensitive)"
  type        = string
  validation {
    condition     = contains(["linux", "windows"], lower(var.os_type))
    error_message = "Dozwolone wartości: 'linux' lub 'windows'"
  }
}

# Konfiguracja Azure
variable "subscription_id" {
  description = "Docelowa subskrypcja Azure (pobierana z zmiennych środowiskowych)"
  type        = string
}

# Bezpieczeństwo dostępu
variable "ssh_public_key" {
  description = "Klucz publiczny w formacie OpenSSH (generowany automatycznie)"
  type        = string
}

variable "ssh_private_key" {
  description = "Prywatny klucz SSH (przechowywany w Azure Key Vault)"
  type        = string
  sensitive   = true  # Nigdy nie pokazywany w outputach
}

# Lokalizacja zasobów
variable "location" {
  description = "Region Azure zgodny z konwencją nazewnictwa (np. 'West Europe')"
  type        = string
  default     = "West Europe"
}

variable "image_name" {
  description = "Nazwa obrazu maszyny wirtualnej"
  type        = string
  default     = "UbuntuLTS"  # Wartość domyślna dla szkoleń
  
}
