# File: packer/windows10-pro.pkr.hcl
# Opis: Definicja obrazu Packer dla Windows 10 Pro (22H2) w Azure.
#       Instaluje podstawowe oprogramowanie edukacyjne/biurowe za pomocą Chocolatey
#       i wykonuje podstawową optymalizację oraz Sysprep.
#
# Użycie:
#   1. Utwórz plik `credentials.pkrvars.hcl` z sekretami Azure.
#   2. Uruchom: packer build -var-file=credentials.pkrvars.hcl .

packer {
  required_plugins {
    # Deklaracja wymaganego pluginu Azure.
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2" # Użyj odpowiedniej wersji pluginu Azure.
    }
  }
}

# Zmienne wrażliwe (sekrety Azure) - dostarczane z zewnątrz.
variable "tenant_id" {
  type        = string
  sensitive   = true
  description = "ID Tenanta Azure Active Directory."
}
variable "subscription_id" {
  type        = string
  sensitive   = true
  description = "ID Subskrypcji Azure."
}
variable "client_id" {
  type        = string
  sensitive   = true
  description = "Client ID (Application ID) dla Service Principal."
}
variable "client_secret" {
  type        = string
  sensitive   = true
  description = "Client Secret dla Service Principal."
}

# Definicja źródła (buildera) Azure ARM dla Windows 10.
source "azure-arm" "windows10" {
  # Uwierzytelnianie.
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret

  # Nazwa i grupa zasobów dla finalnego obrazu.
  managed_image_name                = "windows10-pro"    # Stała nazwa obrazu.
  managed_image_resource_group_name = "packer-images-rg" # Dedykowana RG na obrazy Packer.
  location                          = "West Europe"      # Region budowy i zapisu.

  # Konfiguracja systemu operacyjnego i VM budującej.
  os_type = "Windows"
  vm_size = "Standard_D2s_v3" # Rozsądny rozmiar dla budowy Windows.

  # Obraz bazowy z Azure Marketplace (Windows 10 Pro, wersja 22H2).
  image_publisher = "MicrosoftWindowsDesktop"
  image_offer     = "Windows-10"
  image_sku       = "win10-22h2-pro"
  image_version   = "latest" # Użyj najnowszej wersji obrazu bazowego.

  # Konfiguracja komunikatora WinRM używanego przez Packer do łączenia się z VM Windows.
  communicator   = "winrm"
  winrm_use_ssl  = true     # Używaj szyfrowanego połączenia WinRM (HTTPS).
  winrm_insecure = true     # Ignoruj błędy certyfikatu SSL (typowe i często konieczne w Azure).
  winrm_timeout  = "60m"    # Dłuższy timeout dla operacji WinRM (instalacja oprogramowania może trwać).
  winrm_username = "packer" # Domyślna nazwa użytkownika tworzona przez Packer dla WinRM.

  # Można dodać azure_tags podobnie jak w pliku Ubuntu.
  azure_tags = {
    Environment = "Build"
    Builder     = "Packer"
    ImageName   = "windows10-pro"
    OsType      = "Windows"
  }
}

# Definicja procesu budowy obrazu Windows 10.
build {
  # Nazwa buildu w logach Packera.
  name = "windows10-pro-build"
  # Użyj źródła zdefiniowanego powyżej.
  sources = ["source.azure-arm.windows10"]

  # --- Kroki Provisioningu (wykonywane sekwencyjnie) ---

  # Krok 1: Podstawowa optymalizacja systemu Windows.
  provisioner "powershell" {
    inline = [
      "Write-Output 'Rozpoczynam instalację pakietu edukacyjnego na Windows 10...'",
      "Write-Output 'Optymalizacja systemu: Wyłączanie niektórych usług...'",
      "# Wyłączanie usług telemetrii i 'ulepszeń'",
      "Set-Service -Name DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue",        # Connected User Experiences and Telemetry
      "Set-Service -Name dmwappushservice -StartupType Disabled -ErrorAction SilentlyContinue", # Dmwappushservice (Device Management Wireless Application Protocol)
      "Set-Service -Name SysMain -StartupType Disabled -ErrorAction SilentlyContinue",          # SysMain (dawniej Superfetch)

      "# Wyłączenie hibernacji dla oszczędności miejsca na dysku w obrazie.",
      "Write-Output 'Wyłączanie hibernacji (powercfg /h off)...'",
      "powercfg /h off"
    ]
    max_retries = 3     # Ponów próbę w razie błędu (np. chwilowy problem z usługą).
    timeout     = "10m" # Limit czasu dla tego bloku.
  }

  # Krok 2: Instalacja menedżera pakietów Chocolatey.
  provisioner "powershell" {
    inline = [
      "Write-Output 'Instalacja Chocolatey...'",
      "# Ustawienie polityki wykonywania skryptów PowerShell tylko dla bieżącego procesu.",
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "# Upewnienie się, że używany jest co najmniej TLS 1.2 do pobrania skryptu instalacyjnego.",
      "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072",
      "# Pobranie i wykonanie oficjalnego skryptu instalacyjnego Chocolatey.",
      "Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))",
      "# Krótkie oczekiwanie, aby Chocolatey mógł się w pełni zainicjalizować.",
      "Write-Output 'Oczekiwanie po instalacji Chocolatey...'",
      "Start-Sleep -Seconds 10"
    ]
    max_retries = 3
    timeout     = "10m"
  }

  # Krok 3: Instalacja podstawowego oprogramowania za pomocą Chocolatey.
  provisioner "powershell" {
    inline = [
      "Write-Output 'Instalacja podstawowego oprogramowania (przeglądarki, edytor, archiwizer)...'",
      "choco install -y googlechrome --limit-output", # Przeglądarka Google Chrome
      "Start-Sleep -Seconds 10",                      # Pauza między instalacjami
      "choco install -y firefox --limit-output",      # Przeglądarka Mozilla Firefox
      "Start-Sleep -Seconds 10",
      "choco install -y notepadplusplus --limit-output", # Edytor tekstu Notepad++
      "Start-Sleep -Seconds 10",
      "choco install -y 7zip --limit-output", # Archiwizer 7-Zip
      "Start-Sleep -Seconds 10"
    ]
    max_retries = 3     # Zwiększ liczbę prób, jeśli sieć jest niestabilna.
    timeout     = "20m" # Dłuższy timeout dla instalacji pakietów.
  }

  # Krok 4: Instalacja pakietu biurowego i oprogramowania multimedialnego.
  provisioner "powershell" {
    inline = [
      "Write-Output 'Instalacja pakietu biurowego (LibreOffice) i multimediów (VLC, GIMP)...'",
      "choco install -y libreoffice-still --limit-output", # Pakiet biurowy LibreOffice (wersja stabilna)
      "Start-Sleep -Seconds 10",
      "choco install -y vlc --limit-output", # Odtwarzacz multimedialny VLC
      "Start-Sleep -Seconds 10",
      "choco install -y gimp --limit-output", # Edytor grafiki GIMP
      "Start-Sleep -Seconds 10"
    ]
    max_retries = 3
    timeout     = "30m" # Timeout może być dłuższy dla większych pakietów jak LibreOffice.
  }

  # Krok 5: Instalacja narzędzi programistycznych.
  provisioner "powershell" {
    inline = [
      "Write-Output 'Instalacja narzędzi programistycznych (Python, VSCode, R, RStudio)...'",
      "choco install -y python --limit-output", # Python 3
      "Start-Sleep -Seconds 15",                # Python może wymagać dłuższego czasu na setup
      "choco install -y vscode --limit-output", # Visual Studio Code
      "Start-Sleep -Seconds 10",
      "choco install -y r.project --limit-output", # Środowisko R
      "Start-Sleep -Seconds 15",                   # R może wymagać dłuższego czasu
      "choco install -y r.studio --limit-output",  # RStudio IDE
      "Start-Sleep -Seconds 15"                    # RStudio może wymagać dłuższego czasu
    ]
    max_retries = 3
    timeout     = "30m"
  }

  # Krok 6: Instalacja narzędzi komunikacyjnych.
  provisioner "powershell" {
    inline = [
      "Write-Output 'Instalacja narzędzi komunikacyjnych (Zoom, Teams)...'",
      "choco install -y zoom --limit-output", # Zoom Client
      "Start-Sleep -Seconds 10",
      "choco install -y microsoft-teams --limit-output", # Microsoft Teams (wersja machine-wide installer)
      "Start-Sleep -Seconds 10"
    ]
    max_retries = 3
    timeout     = "20m"
  }

  # Krok 7: Instalacja narzędzi naukowych/edukacyjnych.
  provisioner "powershell" {
    inline = [
      "Write-Output 'Instalacja narzędzi naukowych (Zotero, Anki)...'",
      "choco install -y zotero --limit-output", # Menedżer bibliografii Zotero
      "Start-Sleep -Seconds 10",
      "choco install -y anki --limit-output", # Program do fiszek Anki
      "Start-Sleep -Seconds 10"
    ]
    max_retries = 3
    timeout     = "20m"
  }

  # Krok 8: Czyszczenie końcowe i optymalizacja rozmiaru obrazu.
  provisioner "powershell" {
    inline = [
      "Write-Output 'Czyszczenie niepotrzebnych plików tymczasowych...'",
      "# Usuń zawartość katalogów tymczasowych użytkownika i systemu.",
      "Remove-Item -Path $env:TEMP\\* -Recurse -Force -ErrorAction SilentlyContinue",
      "Remove-Item -Path \"C:\\Windows\\Temp\\*\" -Recurse -Force -ErrorAction SilentlyContinue",
      "# Opróżnij kosz systemowy.",
      "Clear-RecycleBin -Force -ErrorAction SilentlyContinue",

      "# Kompresja plików systemowych w celu zmniejszenia rozmiaru finalnego obrazu.",
      "Write-Output 'Kompresja dysku systemowego (CompactOS)...'",
      "Compact.exe /CompactOS:always", # Może zająć chwilę

      "Write-Output 'Instalacja i podstawowe czyszczenie zakończone!'"
    ]
    max_retries = 3
    timeout     = "20m" # Kompresja może zająć czas.
  }

  # Krok 9: Przygotowanie obrazu do generalizacji za pomocą Sysprep.
  # Sysprep usuwa unikalne identyfikatory systemu (SID itp.), przygotowując obraz
  # do wdrożenia na wielu maszynach. Jest to kluczowy krok dla obrazów Windows.
  provisioner "powershell" {
    inline = [
      "Write-Output 'Przygotowanie obrazu do generalizacji (Sysprep)...'",
      "# (Opcjonalnie) Usuń istniejący plik unattend.xml, jeśli istnieje, aby uniknąć konfliktów.",
      "if (Test-Path $env:SystemRoot\\windows\\system32\\Sysprep\\unattend.xml) { Remove-Item $env:SystemRoot\\windows\\system32\\Sysprep\\unattend.xml -Force }",
      "# Uruchom Sysprep: /oobe (start w trybie Out-of-Box Experience), /generalize (usuń unikalne info), /quiet (bez UI), /quit (zakończ po zakończeniu).",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit",
      "# Pętla oczekująca na zakończenie procesu Sysprep.",
      "# Sysprep zmienia stan w rejestrze; czekamy, aż osiągnie stan IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE.",
      "# Jest to konieczne, aby Packer wiedział, kiedy może bezpiecznie wyłączyć VM do przechwycenia obrazu.",
      "Write-Output 'Oczekiwanie na zakończenie Sysprep (sprawdzanie stanu w rejestrze)...'",
      "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output ('Aktualny stan Sysprep: ' + $imageState.ImageState); Start-Sleep -s 10 } else { Write-Output 'Sysprep zakończony pomyślnie!'; break } }",
      "Write-Output 'VM jest gotowa do przechwycenia przez Packer.'"
    ]
    # Nie ponawiaj próby Sysprep automatycznie w razie błędu.
    max_retries = 0
    # Dłuższy timeout dla Sysprep.
    timeout = "30m"
  }
}