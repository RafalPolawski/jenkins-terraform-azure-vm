# File: terraform/modules/network/variables.tf
# Zmienne wejściowe wymagane przez moduł sieciowy.

variable "user_id" {
  description = "Unikalny identyfikator użytkownika, używany do nazewnictwa zasobów sieciowych."
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  description = "Nazwa grupy zasobów Azure, w której zostaną utworzone zasoby sieciowe."
  type        = string
}

variable "location" {
  description = "Region Azure, w którym zostaną utworzone zasoby sieciowe."
  type        = string
}

variable "allowed_source_ips" {
  description = "Lista adresów IP lub zakresów CIDR dozwolonych w regule NSG dla ruchu przychodzącego."
  type        = list(string)
}

variable "tags" {
  description = "Mapa tagów do zastosowania dla zasobów sieciowych."
  type        = map(string)
  default     = {}
}
