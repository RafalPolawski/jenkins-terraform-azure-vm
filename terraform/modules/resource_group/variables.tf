# File /terraform/modules/resource_group/variables.tf

# Unikalny identyfikownik użytkownika
variable "user_id" {
  description = "Unikalny identyfikator użytkownika (wymagany dla nazewnictwa i tagów)"
  type        = string
}

# Lokalizacja zasobów
variable "location" {
  description = "Docelowy region Azure"
  type        = string
}

# Tagi
variable "tags" {
  description = "Tagi do przypisania zasobom"
  type        = map(string)
}
