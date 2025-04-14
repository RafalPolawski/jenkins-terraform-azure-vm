# File: terraform/modules/resource_group/variables.tf
# Zmienne wejściowe dla modułu grupy zasobów.

variable "user_id" {
  description = "Unikalny identyfikator użytkownika, używany do nazewnictwa grupy zasobów."
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Region Azure, w którym zostanie utworzona grupa zasobów."
  type        = string
}

variable "tags" {
  description = "Mapa tagów do zastosowania dla grupy zasobów."
  type        = map(string)
  default     = {}
}
