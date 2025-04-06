# File: /packer/windows11-pro.pkr.hcl
# packer build -var-file=credentials.pkrvars.hcl windows11-pro.pkr.hcl
packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

variable "tenant_id" {}
variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}

source "azure-arm" "windows11" {
  tenant_id        = var.tenant_id
  subscription_id  = var.subscription_id
  client_id        = var.client_id
  client_secret    = var.client_secret

  managed_image_name                = "windows11-pro"
  managed_image_resource_group_name = "packer-images-rg"
  location                          = "West Europe"

  os_type  = "Windows"
  vm_size  = "Standard_D2s_v3"

  image_publisher = "MicrosoftWindowsDesktop"
  image_offer     = "Windows-11"
  image_sku       = "win11-24h2-pro"
  image_version   = "latest"

  communicator = "winrm"
  winrm_use_ssl = true
  winrm_insecure = true
  winrm_timeout = "60m"
  winrm_username = "packer"
}

build {
  sources = ["source.azure-arm.windows11"]


  provisioner "powershell" {
    inline = [
      "Write-Output 'Rozpoczynam instalację pakietu edukacyjnego na Windows 11...'",
      "Write-Output 'Optymalizacja systemu...'",
      "Set-Service -Name DiagTrack -StartupType Disabled",
      "Set-Service -Name dmwappushservice -StartupType Disabled",
      "Set-Service -Name SysMain -StartupType Disabled",
      
      "# Wyłączenie hibernacji dla oszczędności miejsca",
      "powercfg /h off"
    ]
    max_retries = 3
    timeout     = "10m"
  }
  

  provisioner "powershell" {
    inline = [
      "Write-Output 'Instalacja Chocolatey...'",
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072",
      "Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))",
      "Start-Sleep -Seconds 10"
    ]
    max_retries = 3
    timeout     = "10m"
  }
  

  provisioner "powershell" {
    inline = [
      "Write-Output 'Instalacja podstawowego oprogramowania...'",
      "choco install -y googlechrome --limit-output",
      "Start-Sleep -Seconds 10",
      "choco install -y firefox --limit-output",
      "Start-Sleep -Seconds 10",
      "choco install -y notepadplusplus --limit-output",
      "Start-Sleep -Seconds 10",
      "choco install -y 7zip --limit-output",
      "Start-Sleep -Seconds 10"
    ]
    max_retries = 3
    timeout     = "20m"
  }
  

  provisioner "powershell" {
    inline = [
      "Write-Output 'Instalacja pakietu biurowego i multimediów...'",
      "choco install -y libreoffice-still --limit-output",
      "Start-Sleep -Seconds 10",
      "choco install -y vlc --limit-output",
      "Start-Sleep -Seconds 10",
      "choco install -y gimp --limit-output",
      "Start-Sleep -Seconds 10"
    ]
    max_retries = 3
    timeout     = "30m"
  }
  

  provisioner "powershell" {
    inline = [
      "Write-Output 'Instalacja narzędzi programistycznych...'",
      "choco install -y python --limit-output",
      "Start-Sleep -Seconds 15",
      "choco install -y vscode --limit-output",
      "Start-Sleep -Seconds 10",
      "choco install -y r.project --limit-output",
      "Start-Sleep -Seconds 15",
      "choco install -y r.studio --limit-output",
      "Start-Sleep -Seconds 15"
    ]
    max_retries = 3
    timeout     = "30m"
  }
  

  provisioner "powershell" {
    inline = [
      "Write-Output 'Instalacja narzędzi komunikacyjnych...'",
      "choco install -y zoom --limit-output",
      "Start-Sleep -Seconds 10",
      "choco install -y microsoft-teams --limit-output",
      "Start-Sleep -Seconds 10"
    ]
    max_retries = 3
    timeout     = "20m"
  }
  

  provisioner "powershell" {
    inline = [
      "Write-Output 'Instalacja narzędzi naukowych...'",
      "choco install -y zotero --limit-output",
      "Start-Sleep -Seconds 10",
      "choco install -y anki --limit-output",
      "Start-Sleep -Seconds 10"
    ]
    max_retries = 3
    timeout     = "20m"
  }
  

  provisioner "powershell" {
    inline = [
      "Write-Output 'Czyszczenie niepotrzebnych plików...'",
      "Remove-Item -Path $env:TEMP\\* -Recurse -Force -ErrorAction SilentlyContinue",
      "Remove-Item -Path \"C:\\Windows\\Temp\\*\" -Recurse -Force -ErrorAction SilentlyContinue",
      "Clear-RecycleBin -Force -ErrorAction SilentlyContinue",
      
      "# Kompresja dysku dla oszczędności miejsca",
      "Write-Output 'Kompresja dysku...'",
      "Compact.exe /CompactOS:always",
      
      "Write-Output 'Instalacja zakończona! Obraz został zoptymalizowany dla studentów.'"
    ]
    max_retries = 3
    timeout     = "20m"
  }
  

  provisioner "powershell" {
    inline = [
      "Write-Output 'Przygotowanie obrazu (Sysprep)...'",
      "if (Test-Path $env:SystemRoot\\windows\\system32\\Sysprep\\unattend.xml) { Remove-Item $env:SystemRoot\\windows\\system32\\Sysprep\\unattend.xml -Force }",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit",
      "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $imageState.ImageState; Start-Sleep -s 10 } else { break } }"
    ]
    max_retries = 0 
    timeout     = "30m"
  }
}