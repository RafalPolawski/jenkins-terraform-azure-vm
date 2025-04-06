# Unikalny identyfikator użytkownika
variable "user_id" {
  description = "Unikalny identyfikator użytkownika (wymagany dla nazewnictwa i tagów)"
  type        = string
}

# Nazwa istniejącej grupy zasobów
variable "resource_group_name" {
  description = "Nazwa istniejącej grupy zasobów (output z modułu resource_group)"
  type        = string
}

# Region zgodny z notacją Azure (np. "West Europe")
# Lista dostępnych: az account list-locations --output table
variable "location" {
  description = "Docelowy region Azure"
  type        = string
}

# Zmienna warunkująca architekturę - wybór między dwoma wariantami
variable "os_type" {
  description = "System operacyjny maszyny wirtualnej: 'linux' lub 'windows' (case-insensitive)"
  type        = string
}