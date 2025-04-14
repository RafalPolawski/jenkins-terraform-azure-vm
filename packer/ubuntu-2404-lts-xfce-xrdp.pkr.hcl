# File: packer/ubuntu-2404-lts-xfce-xrdp.pkr.hcl
# Opis: Definicja obrazu Packer dla Ubuntu 24.04 LTS z GUI (XFCE) i XRDP w Azure.
#       Używa zewnętrznego skryptu 'setup-ubuntu-2404-lts-xfce-xrdp.sh' do provisioningu.
#
# Użycie:
#   1. Upewnij się, że masz zainstalowany Packer (https://www.packer.io/downloads).
#   2. Utwórz plik `credentials.pkrvars.hcl` zawierający sekrety Azure
#      (tenant_id, subscription_id, client_id, client_secret).
#   3. Uruchom build z katalogu zawierającego ten plik i podkatalog 'scripts':
#      packer build -var-file=credentials.pkrvars.hcl .
#      (lub z dodatkowymi zmiennymi: packer build -var-file=credentials.pkrvars.hcl -var 'build_version=1.0.1' .)

packer {
  required_plugins {
    # Deklaracja wymaganego pluginu Azure dla Packer.
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2.3" # Użyj najnowszej stabilnej wersji pluginu Azure (lub zgodnie z wymaganiami)
    }
  }
}

# --- Zmienne ---

# Wartości wrażliwe (sekrety) - Zwykle dostarczane przez plik .pkrvars.hcl lub zmienne środowiskowe (PKR_VAR_...).
variable "tenant_id" {
  type        = string
  sensitive   = true
  description = "ID Tenanta (Directory ID) Azure Active Directory."
}
variable "subscription_id" {
  type        = string
  sensitive   = true
  description = "ID Subskrypcji Azure, w której obraz będzie budowany i przechowywany."
}
variable "client_id" {
  type        = string
  sensitive   = true
  description = "Client ID (Application ID) dla Service Principal używanego przez Packer do uwierzytelniania w Azure."
}
variable "client_secret" {
  type        = string
  sensitive   = true
  description = "Client Secret (hasło) dla Service Principal."
}

# Zmienne konfiguracyjne z wartościami domyślnymi - można je nadpisać np. przez '-var'.
variable "image_rg_name" {
  type        = string
  default     = "packer-images-rg"
  description = "Nazwa grupy zasobów Azure, w której zostanie zapisany finalny obraz."
}
variable "image_name_prefix" {
  type        = string
  default     = "ubuntu-2404-lts-xfce-xrdp"
  description = "Prefiks nazwy dla finalnego obrazu Azure Managed Image."
}
variable "azure_location" {
  type        = string
  default     = "West Europe"
  description = "Region Azure, w którym zostanie utworzona tymczasowa VM budująca i zapisany finalny obraz."
}
variable "vm_build_size" {
  type        = string
  default     = "Standard_D2s_v3" # Zapewnia rozsądną wydajność podczas instalacji GUI.
  description = "Rozmiar (SKU) tymczasowej maszyny wirtualnej Azure używanej do budowy obrazu."
}
variable "admin_username" {
  type        = string
  default     = "azureuser" # Standardowa nazwa użytkownika tworzona przez Azure dla obrazów Linux.
  description = "Nazwa użytkownika administracyjnego tworzonego przez Azure na tymczasowej VM. Ta nazwa jest przekazywana jako argument ($1) do skryptu provisioningu."
}
variable "build_version" {
  type        = string
  default     = "" # np. "1.0.0" lub zostaw puste dla timestampu
  description = "Opcjonalny tag wersji (np. semver). Jeśli pusty, użyty zostanie timestamp."
}

# --- Zasoby lokalne (generowanie dynamicznych wartości) ---
locals {
  # Generuje timestamp w formacie YYYYMMDD-HHMM, jeśli zmienna build_version nie została podana.
  timestamp = var.build_version != "" ? var.build_version : formatdate("YYYYMMDD-HHMM", timestamp())

  # Definiuje finalną nazwę obrazu. Obecnie używana jest stała nazwa bez wersji/timestampu.
  # Odkomentuj poniższą linię (i zakomentuj następną), jeśli chcesz dodawać wersję/timestamp do nazwy obrazu.
  # managed_image_full_name = "${var.image_name_prefix}-${local.timestamp}"
  managed_image_full_name = var.image_name_prefix

  # Nazwa tymczasowej grupy zasobów używanej podczas procesu budowy. Zostanie automatycznie usunięta.
  temp_rg_name = "packer-temp-rg-${var.image_name_prefix}"
}

# --- Źródło Azure (Builder) ---
# Definiuje, jak Packer ma zbudować obraz w Azure.
source "azure-arm" "ubuntu-gui" {
  # Uwierzytelnianie za pomocą Service Principal (dane z sekcji 'variable').
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret

  # Konfiguracja finalnego obrazu Azure Managed Image.
  managed_image_resource_group_name = var.image_rg_name             # Grupa zasobów docelowa.
  managed_image_name                = local.managed_image_full_name # Nazwa docelowa obrazu.
  location                          = var.azure_location            # Region docelowy.

  # Definicja obrazu bazowego z Azure Marketplace.
  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts" # Oficjalna oferta dla Ubuntu 24.04 LTS (Noble Numbat)
  image_sku       = "server"           # Użyj standardowego obrazu serwerowego Gen2 (domyślnie)
  image_version   = "latest"           # Zawsze używaj najnowszej dostępnej wersji obrazu bazowego dla poprawek bezpieczeństwa.

  # Konfiguracja tymczasowej maszyny wirtualnej używanej do budowy.
  vm_size                  = var.vm_build_size
  temp_resource_group_name = local.temp_rg_name # Nazwa tymczasowej grupy zasobów (generowana w locals).
  os_disk_size_gb          = 64                 # Zwiększ domyślny rozmiar dysku OS (np. 30GB), aby pomieścić GUI i potencjalne dodatkowe oprogramowanie.

  # Nazwa użytkownika tworzona na tymczasowej VM przez Azure i używana przez Packer do połączenia SSH.
  # Kluczowe: Ta wartość musi być zgodna z oczekiwaniami skryptu provisioningu (przekazywana jako $1).
  ssh_username = var.admin_username

  # Tagi Azure stosowane zarówno do zasobów tymczasowych (VM, RG, etc.), jak i do finalnego obrazu.
  azure_tags = {
    Environment = "Build"
    Builder     = "Packer"
    ImagePrefix = var.image_name_prefix
    BuildId     = local.timestamp # Wersja lub timestamp
    OsType      = "Linux"         # Dodatkowy tag identyfikujący OS
  }
}

# --- Proces Budowy (Build) ---
# Definiuje kroki wykonywane podczas budowy obrazu.
build {
  name = var.image_name_prefix # Nazwa tego konkretnego bloku build (widoczna w logach Packer).

  # Określa, które źródło (builder) ma być użyte dla tego bloku build.
  sources = ["source.azure-arm.ubuntu-gui"] # Odnosi się do nazwy bloku 'source' zdefiniowanego powyżej.

  # Krok 1: Wykonaj zewnętrzny skrypt provisioningu.
  provisioner "shell" {
    # Ścieżka do skryptu powłoki, który ma być wykonany na tymczasowej VM.
    script = "scripts/setup-ubuntu-2404-lts-xfce-xrdp.sh"

    # Komenda używana do wykonania skryptu.
    # sudo -S: Wykonaj jako root, czytając hasło ze standardowego wejścia (Packer to obsłuży).
    # /bin/bash -e: Wykonaj skrypt za pomocą bash z opcją exit-on-error.
    # '{{.Path}}': Placeholder Packer oznaczający ścieżkę do przesłanego skryptu na VM.
    # '${var.admin_username}': Przekaż nazwę użytkownika jako pierwszy argument ($1) do skryptu.
    execute_command = "sudo -S /bin/bash -e '{{.Path}}' '${var.admin_username}'"

    # Przekaż zmienne środowiskowe do środowiska wykonania skryptu.
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive" # Kluczowe dla uniknięcia promptów apt.
    ]
  }

  # Można dodać kolejne kroki 'provisioner' tutaj, jeśli są potrzebne
  # (np. kopiowanie plików, uruchamianie Ansible itp.).
}