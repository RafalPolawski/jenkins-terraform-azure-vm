# 🛠️ Automatyczne Wdrażanie Maszyn Wirtualnych w Azure (IaC + CI/CD)

## 📌 Opis projektu

Celem projektu jest stworzenie zautomatyzowanego systemu do wdrażania i zarządzania **maszynami wirtualnymi (VM) w chmurze Azure**. System jest przeznaczony dla środowisk laboratoryjnych, szkoleniowych lub testowych, gdzie użytkownicy (np. studenci, deweloperzy) potrzebują tymczasowego dostępu do prekonfigurowanych maszyn.

Projekt wykorzystuje podejście **Infrastructure as Code (IaC)** oraz procesy **CI/CD** do zapewnienia powtarzalności, szybkości i spójności wdrożeń. Kluczowe narzędzia to Terraform, Packer, Jenkins oraz Ansible.

## 🔧 Technologie

*   **IaC:**
    *   **Terraform (`>= 1.1.0`):** Definiowanie i zarządzanie infrastrukturą Azure (Sieć, VM, Grupy Zasobów).
    *   **Packer (`~> 1.7` for HCL2):** Budowanie niestandardowych, prekonfigurowanych obrazów VM (Linux/Windows).
*   **Automatyzacja / CI/CD:**
    *   **Jenkins:** Orchestracja całego procesu (pipeline), zarządzanie parametrami, użytkownikami, harmonogramowanie zadań (np. czyszczenie).
    *   **Groovy:** Język używany w Jenkinsfiles (Pipeline as Code).
*   **Konfiguracja VM:**
    *   **Ansible (opcjonalnie):** Konfiguracja maszyn wirtualnych Linux po ich utworzeniu (instalacja oprogramowania).
    *   **Shell Scripts (Bash):** Używane przez Packer (Linux) i Jenkins.
    *   **PowerShell:** Używane przez Packer (Windows) i Jenkins.
*   **Platforma Chmurowa:**
    *   **Microsoft Azure:** Docelowe środowisko chmurowe.
        *   Azure Virtual Machines
        *   Azure Networking (VNet, Subnet, NSG, Public IP)
        *   Azure Storage Account (dla stanu Terraform)
        *   Azure Key Vault (dla sekretów, np. kluczy SSH)
        *   Azure Managed Images
*   **Narzędzia Pomocnicze:**
    *   **Git:** System kontroli wersji dla kodu IaC, skryptów i Jenkinsfiles.
    *   **Azure CLI:** Używane do zarządzania stanem VM (start/stop/restart) i przez job czyszczący.
    *   **Chocolatey:** Menedżer pakietów używany w Packerze dla Windows.
    *   Narzędzia na agencie Jenkins (np. `pwgen`, `puttygen`, `zip`, `openssl` - zależnie od funkcji w Jenkinsfile).

## ✨ Kluczowe Funkcje

*   **Parametryzowane Wdrażanie VM:** Użytkownicy mogą wybierać system operacyjny, obraz, czas życia VM i opcjonalne oprogramowanie przez interfejs Jenkins.
*   **Wsparcie dla Obrazów Niestandardowych:** Możliwość użycia obrazów VM zbudowanych za pomocą Packer (np. Ubuntu z GUI, Windows 10 z oprogramowaniem) obok standardowych obrazów z Azure Marketplace.
*   **Zdalny i Izolowany Stan Terraform:** Pliki stanu Terraform (`.tfstate`) są przechowywane bezpiecznie w Azure Blob Storage, z oddzielnym plikiem dla każdego użytkownika (`<user_id>.tfstate`), co zapobiega konfliktom.
*   **Automatyczne Zarządzanie Cyklem Życia VM:**
    *   Maszyny są tworzone ze znacznikiem czasu (`DestroyTimestampUTC`) określającym, kiedy mają zostać usunięte.
    *   Dedykowany job Jenkins (`Jenkinsfile-Automatyczne-Czyszczenie-VM`) cyklicznie sprawdza tagi i automatycznie wyzwala niszczenie przeterminowanych maszyn.
*   **Bezpieczne Zarządzanie Sekretami:**
    *   Poświadczenia Azure (Service Principal) przechowywane w Jenkins Credentials.
    *   Klucze SSH dla maszyn Linux są generowane, bezpiecznie przechowywane w Azure Key Vault i usuwane podczas niszczenia VM.
*   **Automatyzacja Dostępu:**
    *   Automatyczne generowanie kluczy SSH dla Linux.
    *   Automatyczne generowanie haseł dla Windows.
    *   Wysyłanie danych dostępowych (klucze SSH w zabezpieczonym ZIP, hasło Windows, plik RDP) do użytkownika emailem (wymaga `emailext-plugin`).
*   **Zarządzanie Stanem Zasilania VM:** Możliwość uruchamiania, zatrzymywania (deallocate) i restartowania istniejących VM przez Jenkins.
*   **Izolacja Środowiska Jenkins:** Dedykowane workspace'y dla każdego użytkownika w Jenkinsie, czyszczone po zakończeniu buildu.
*   **Modułowa Struktura Terraform:** Kod Terraform jest podzielony na moduły (Resource Group, Network, VM) dla lepszej organizacji i reużywalności.

## ⚙️ Jak to działa? (Przepływ pracy)

1.  **Użytkownik:** Wyzwala główny job Jenkins (`Jenkinsfile`), podając parametry (Akcja, OS, Obraz, Czas życia, etc.).
2.  **Jenkins (Inicjalizacja):**
    *   Określa efektywnego użytkownika (uruchamiający lub `TARGET_USER_ID` z joba czyszczącego).
    *   Tworzy/czyści dedykowany workspace dla użytkownika.
    *   Pobiera kod źródłowy (Terraform, Packer scripts, Ansible) do workspace.
3.  **Jenkins (Akcja 'create'):**
    *   (Linux) Generuje parę kluczy SSH, zapisuje je w Azure Key Vault (nazwane z `user_id`).
    *   Generuje nazwę użytkownika admina i hasło (dla Windows).
    *   Oblicza `DestroyTimestampUTC` na podstawie parametru `DESTROY_AFTER`.
    *   Inicjalizuje Terraform (`terraform init`), konfigurując backend Azure Storage dla stanu użytkownika (`<user_id>.tfstate`).
    *   Uruchamia `terraform apply`, przekazując zmienne (OS, obraz, dane logowania, `user_id`, `destroy_timestamp_utc`, etc.).
4.  **Terraform:**
    *   Tworzy lub aktualizuje zasoby w Azure zgodnie z definicją w modułach (`./terraform/modules`).
    *   Tworzy grupę zasobów, sieć (VNet, Subnet, NSG, Public IP, NIC).
    *   Wybiera odpowiedni obraz (Marketplace lub niestandardowy z Azure Compute Gallery/Managed Image).
    *   Tworzy VM (Linux lub Windows) z odpowiednimi danymi logowania (klucz SSH lub hasło).
    *   Stosuje tagi, w tym `OwnerId` i `DestroyTimestampUTC`.
    *   Zwraca dane wyjściowe (IP, dane logowania) do Jenkinsa.
5.  **Jenkins (Konfiguracja - opcjonalnie):**
    *   (Linux 'create') Jeśli wybrano, uruchamia playbook Ansible (`ansible/`) na nowo utworzonej VM, używając danych wyjściowych z Terraform i pobranego klucza SSH.
6.  **Jenkins (Powiadomienie 'create'):**
    *   Pobiera dane dostępowe z outputu Terraform.
    *   (Linux) Konwertuje klucz SSH do formatu PPK, tworzy zaszyfrowany ZIP, wysyła dwa emaile (jeden z ZIPem, drugi z hasłem do ZIPa i instrukcją).
    *   (Windows) Generuje plik `.rdp`, wysyła email z hasłem, instrukcją i załączonym plikiem `.rdp`.
7.  **Jenkins (Akcja 'destroy'):**
    *   Inicjalizuje Terraform (`terraform init`) dla stanu użytkownika.
    *   Uruchamia `terraform destroy`.
    *   (Linux) Usuwa klucze SSH użytkownika z Azure Key Vault.
8.  **Jenkins (Akcje 'start'/'stop'/'restart'):**
    *   Używa Azure CLI do znalezienia VM użytkownika (po tagu `OwnerId`).
    *   Wykonuje odpowiednią komendę `az vm start/deallocate/restart`.
9.  **Jenkins (Job Czyszczący - `Jenkinsfile-Automatyczne-Czyszczenie-VM`):**
    *   Uruchamiany cyklicznie (np. co 15 minut).
    *   Używa Azure CLI do pobrania listy VM z tagami `DestroyTimestampUTC`, `OwnerId`, `OsType`.
    *   Dla każdej VM porównuje `DestroyTimestampUTC` z aktualnym czasem.
    *   Jeśli czas minął, wyzwala główny job Jenkins (`wait: false`) z `ACTION=destroy` i `TARGET_USER_ID` ustawionym na `OwnerId` z tagu VM.
10. **Jenkins (Zawsze na końcu):** Czyści workspace użytkownika.

## 📁 Struktura repozytorium
```Struktura repozytorium
.
├── ansible/                 # (Opcjonalnie) Role i playbooki Ansible do konfiguracji Linux VM
│   └── universal_setup.yml  # Przykładowy playbook (może tu być więcej plików/ról)
├── packer/                  # Konfiguracje Packer do budowy obrazów VM
│   ├── scripts/             # Skrypty provisioningu używane przez Packer
│   │   └── setup-ubuntu-2404-lts-xfce-xrdp.sh # Skrypt dla Ubuntu
│   │   # Mogą tu być inne skrypty, np. dla Windows
│   ├── ubuntu-2404-lts-xfce-xrdp.pkr.hcl # Definicja obrazu Packer dla Ubuntu z GUI
│   ├── windows10-pro.pkr.hcl             # Definicja obrazu Packer dla Windows 10 Pro
│   └── credentials.pkrvars.hcl.example   # Przykład pliku ze zmiennymi Azure dla Packer
├── terraform/               # Pliki Terraform definiujące infrastrukturę
│   ├── modules/             # Moduły Terraform (reusable components)
│   │   ├── network/         # Moduł sieciowy
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── resource_group/  # Moduł grupy zasobów
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── vm/              # Moduł maszyny wirtualnej
│   │       ├── main.tf      # Logika tworzenia VM (Linux/Windows)
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── images.tf    # Definicje i mapowania obrazów VM
│   ├── main.tf              # Główny plik orkiestracji modułów
│   ├── variables.tf         # Główne zmienne wejściowe dla root module
│   ├── outputs.tf           # Główne wartości wyjściowe z root module
│   ├── providers.tf         # Konfiguracja dostawców Terraform (AzureRM, Random)
│   └── backend.tf           # Generowany dynamicznie przez Jenkins (nie commitować)
├── Jenkinsfile              # Główny pipeline Jenkins (zarządzanie tworzeniem/niszczeniem VM)
├── Jenkinsfile-Automatyczne-Czyszczenie-VM # Pipeline Jenkins dla joba cyklicznego czyszczenia
├── .gitignore               # Pliki i katalogi ignorowane przez Git
└── README.md                # Ten plik dokumentacji
```

## 🚀 Wymagania wstępne

*   **Konto Microsoft Azure:** Aktywna subskrypcja (może być Trial, ale z uwzględnieniem limitów rdzeni/zasobów).
*   **Service Principal (SPN) w Azure:** Konto aplikacji z odpowiednimi uprawnieniami (RBAC) do tworzenia/zarządzania grupami zasobów, VM, siecią, Key Vault, Storage, Managed Images. Minimalne wymagane uprawnienia: `Contributor` na poziomie subskrypcji lub bardziej szczegółowe role dla poszczególnych usług (zalecane).
*   **Zasoby Azure przygotowane wstępnie:**
    *   Grupa zasobów dla stanu Terraform (np. `tfstate-rg`).
    *   Konto Azure Storage (v2) w tej grupie (np. `tfstatestorage...`).
    *   Kontener Blob w tym koncie storage (np. `tfstate-students`).
    *   Azure Key Vault (np. `myKeyVault...`) do przechowywania kluczy SSH. SPN Jenkinsa musi mieć uprawnienia do zapisu/odczytu/usuwania/czyszczenia (`purge`) sekretów.
    *   (Opcjonalnie) Grupa zasobów dla obrazów Packer (np. `packer-images-rg`). SPN musi mieć uprawnienia do zapisu w tej RG.
*   **Serwer Jenkins:** Działająca instancja Jenkins.
*   **Pluginy Jenkins:**
    *   `Pipeline` (zwykle domyślnie)
    *   `Pipeline: Groovy` (zwykle domyślnie)
    *   `Git plugin` (zwykle domyślnie)
    *   `Workspace Cleanup Plugin`
    *   `Credentials Binding Plugin` (zwykle domyślnie)
    *   `Azure Credentials Plugin` (do przechowywania SPN)
    *   `Build User Vars Plugin` (do pobierania danych użytkownika Jenkins)
    *   `Email Extension Plugin` (emailext - do wysyłania powiadomień)
    *   `Hidden Parameter Plugin` (dla `TARGET_USER_ID`)
*   **Agenty Jenkins:** Skonfigurowane agenty (lub master, jeśli dozwolone) z zainstalowanymi narzędziami:
    *   `Terraform` (`>= 1.1.0`)
    *   `Azure CLI` (zalogowany za pomocą SPN lub skonfigurowany do użycia poświadczeń Jenkins)
    *   `Git`
    *   (Opcjonalnie) `Packer` (jeśli obrazy są budowane przez Jenkins lub lokalnie)
    *   (Opcjonalnie) `Ansible` (jeśli używany do konfiguracji Linux)
    *   Narzędzia pomocnicze używane w `Jenkinsfile`: `pwgen`, `puttygen`, `zip`, `openssl` (dla Linux).
*   **Podstawowa znajomość:** Git, Jenkins, Terraform, Azure, Shell/PowerShell.

## ⚙️ Konfiguracja

1.  **Azure:**
    *   Utwórz Service Principal (SPN) i zanotuj jego `appId` (Client ID), `password` (Client Secret) i `tenant` (Tenant ID).
    *   Utwórz grupę zasobów dla stanu Terraform (np. `tfstate-rg`).
    *   W tej RG utwórz konto Azure Storage v2 (np. `tfstatestorageXYZ`).
    *   Na tym koncie Storage utwórz kontener Blob (np. `tfstate-students`).
    *   Utwórz Azure Key Vault (np. `myKeyVaultXYZ`). Upewnij się, że opcja `purge protection` jest wyłączona, jeśli chcesz, aby `az keyvault secret purge` działało od razu (niezalecane produkcyjnie), lub ustaw krótki `soft-delete retention period`. Nadaj SPN uprawnienia do zarządzania sekretami (`Key Vault Secrets Officer` lub podobna rola).
    *   (Opcjonalnie) Utwórz grupę zasobów dla obrazów Packer (np. `packer-images-rg`).
    *   Przypisz SPN odpowiednie role RBAC (np. `Contributor` na poziomie subskrypcji lub bardziej granularne role dla potrzebnych usług).

2.  **Jenkins:**
    *   Zainstaluj wymagane pluginy wymienione w sekcji "Wymagania wstępne".
    *   Przejdź do **Zarządzanie Jenkins (Manage Jenkins) → Credentials → System → Global credentials**.
    *   Dodaj poświadczenia typu **"Microsoft Azure Service Principal"**:
        *   **ID:** `AZURE_CREDENTIALS` (lub inne ID, ale musi być zgodne ze stałą `AZURE_CREDENTIALS_ID` w `Jenkinsfile-Automatyczne-Czyszczenie-VM` i użyciem w głównym `Jenkinsfile`).
        *   Wprowadź Subscription ID, Client ID, Client Secret, Tenant ID swojego SPN.
    *   Dodaj poświadczenia typu **"Secret text"**:
        *   **ID:** `ADMIN_EMAIL`
        *   **Secret:** Wpisz adres email, z którego będą wysyłane powiadomienia (np. `jenkins-admin@twojadomena.com`). Upewnij się, że serwer Jenkins może wysyłać emaile (skonfigurowany serwer SMTP w Jenkinsie lub plugin Email Extension).
    *   Utwórz dwa joby typu **"Pipeline"**:
        1.  **Główny Job Zarządzania VM (np. "Tworzenie Maszyny Wirtualnej"):**
            *   W sekcji "Pipeline", wybierz **"Pipeline script from SCM"**.
            *   **SCM:** Wybierz "Git".
            *   **Repository URL:** Wpisz URL tego repozytorium Git.
            *   **Branch Specifier:** `*/main` lub `*/master`.
            *   **Script Path:** `Jenkinsfile`
            *   Zaznacz **"This project is parameterized"** - parametry zostaną automatycznie wczytane z `Jenkinsfile`.
            *   Zapisz joba.
        2.  **Job Czyszczący (np. "Automatyczne Czyszczenie VM"):**
            *   W sekcji "Pipeline", wybierz **"Pipeline script from SCM"**.
            *   **SCM:** Wybierz "Git".
            *   **Repository URL:** Wpisz URL tego repozytorium Git.
            *   **Branch Specifier:** `*/main` lub `*/master`.
            *   **Script Path:** `Jenkinsfile-Automatyczne-Czyszczenie-VM`
            *   W sekcji **"Build Triggers"**, zaznacz **"Build periodically"**.
            *   **Schedule:** Wpisz harmonogram, np. `H/15 * * * *` (co 15 minut z losowym opóźnieniem).
            *   Zapisz joba.

3.  **Packer (Opcjonalnie - Budowa Obrazów):**
    *   Jeśli chcesz zbudować własne obrazy (Ubuntu GUI, Windows 10 Pro):
        *   Przejdź do katalogu `packer/`.
        *   Sklonuj plik `credentials.pkrvars.hcl.example` do `credentials.pkrvars.hcl`.
        *   Wypełnij `credentials.pkrvars.hcl` danymi swojego SPN Azure. **Nie commituj tego pliku!** Upewnij się, że jest w `.gitignore`.
        *   Uruchom build dla wybranego obrazu, np.:
            ```bash
            packer build -var-file=credentials.pkrvars.hcl ubuntu-2404-lts-xfce-xrdp.pkr.hcl
            packer build -var-file=credentials.pkrvars.hcl windows10-pro.pkr.hcl
            ```
        *   Zbudowane obrazy pojawią się w grupie zasobów `packer-images-rg` (lub innej zdefiniowanej w zmiennej `image_rg_name`). Nazwy obrazów (`managed_image_name`) muszą być zgodne z tymi użytymi w parametrach `IMAGE_NAME` Jenkinsa i w `terraform/modules/vm/images.tf`.

## 🚀 Użycie

1.  **Przejdź do Głównego Joba Jenkins** (np. "Tworzenie Maszyny Wirtualnej").
2.  Kliknij **"Build with Parameters"**.
3.  Wybierz żądaną **Akcję**:
    *   `create`: Tworzy nową VM dla Ciebie.
    *   `destroy`: Niszczy Twoją istniejącą VM.
    *   `start`: Uruchamia Twoją zatrzymaną VM.
    *   `stop`: Zatrzymuje i dealokuje Twoją VM (zatrzymuje naliczanie opłat za CPU/RAM).
    *   `restart`: Restartuje Twoją VM.
4.  Wybierz **System Operacyjny (OS_TYPE)**: `linux` lub `windows`.
5.  Wybierz **Obraz Systemu (IMAGE_NAME)** z listy dostępnych obrazów (upewnij się, że pasuje do wybranego `OS_TYPE`). Lista zawiera obrazy z Azure Marketplace oraz obrazy niestandardowe (np. te zbudowane przez Packer).
6.  (Tylko dla `create`) Wybierz **Czas życia VM (DESTROY_AFTER)**, po którym zostanie automatycznie usunięta przez job czyszczący.
7.  (Tylko dla `create`, Linux) Opcjonalnie zaznacz oprogramowanie do zainstalowania przez Ansible (`INSTALL_*`).
8.  Kliknij **"Build"**.
9.  Obserwuj postęp w logach konsoli Jenkins.
10. Po zakończeniu buildu (dla akcji `create`), otrzymasz email(e) z danymi dostępowymi (IP, login, hasło/klucz SSH).

**Automatyczne Czyszczenie:** Job "Automatyczne Czyszczenie VM" działa w tle zgodnie z ustalonym harmonogramem (np. co 15 minut). Automatycznie znajduje i wyzwala niszczenie maszyn, których czas życia (określony przez tag `DestroyTimestampUTC` ustawiony podczas tworzenia) minął. Nie wymaga interakcji użytkownika.

## 🔒 Uwagi dotyczące bezpieczeństwa

Projekt ten, szczególnie w obecnej formie, wymaga zwrócenia uwagi na kilka aspektów bezpieczeństwa:

*   **Service Principal (SPN):** Upewnij się, że SPN używany przez Jenkins i Packer ma **minimalne niezbędne uprawnienia (Least Privilege)**. Rola `Contributor` na poziomie subskrypcji jest bardzo szeroka; rozważ bardziej granularne role (np. `Virtual Machine Contributor`, `Network Contributor`, `Key Vault Secrets Officer`, `Storage Blob Data Contributor` itp.) przypisane do odpowiednich zasobów lub grup zasobów.
*   **Sekrety:** Przechowuj sekrety (hasło SPN, klucze API) tylko w bezpiecznych miejscach (Jenkins Credentials, Azure Key Vault). **Nigdy nie commituj sekretów do repozytorium Git!** Używaj `.gitignore` dla plików jak `credentials.pkrvars.hcl` czy `.terraform/`.
*   **Dostęp do Stanu Terraform:** Pliki `.tfstate` zawierają szczegóły infrastruktury, w tym potencjalnie wrażliwe dane. Kontroluj dostęp do konta Azure Storage i kontenera Blob przechowującego te pliki za pomocą RBAC Azure.
*   **Klucze SSH:**
    *   Klucze prywatne są generowane na agencie Jenkins, zapisywane w Azure Key Vault i tymczasowo używane przez Ansible.
    *   Wysyłanie kluczy prywatnych emailem (nawet w zaszyfrowanym ZIP z hasłem w osobnym emailu) jest **ryzykowne**. Rozważ alternatywne, bezpieczniejsze metody dystrybucji (np. mechanizm pobierania przez użytkownika z zabezpieczonej strony, integracja z systemem zarządzania tożsamością).
    *   Mechanizm usuwania i czyszczenia (`purge`) kluczy z Key Vault podczas `destroy` jest ważnym krokiem, ale jego skuteczność zależy od konfiguracji KV (soft-delete).
*   **Hasła Windows:** Hasła są generowane losowo, ale wysyłane emailem w postaci jawnej. **Kluczowe jest, aby użytkownicy zmieniali hasło natychmiast po pierwszym zalogowaniu.** Należy ich o tym wyraźnie poinstruować.
*   **Bezpieczeństwo Sieci:**
    *   Domyślna konfiguracja NSG w `terraform/modules/network/main.tf` (zmienna `allowed_source_ips` z default `["0.0.0.0/0"]`) zezwala na dostęp do portów RDP/SSH/VNC z **całego internetu**. Jest to **bardzo niebezpieczne**. W środowiskach innych niż całkowicie otwarte testowe **należy to bezwzględnie ograniczyć**:
        *   Przekazuj listę dozwolonych IP/CIDR jako parametr do Jenkinsa.
        *   Pobieraj dynamicznie IP użytkownika (jeśli możliwe i bezpieczne).
        *   Wymagaj połączenia przez VPN lub Azure Bastion.
    *   Skrypt Packer dla Ubuntu konfiguruje firewall UFW na VM, co jest dobrą praktyką.
*   **Bezpieczeństwo Obrazów Packer:**
    *   Regularnie aktualizuj obrazy bazowe w konfiguracji Packer (`image_version = "latest"` w `source` pomaga, ale wymaga częstych rebuildów obrazów niestandardowych, aby załapać się na najnowsze poprawki).
    *   Stosuj zasady hardeningu w skryptach provisioningu (przykład w skrypcie Ubuntu).
    *   Rozważ skanowanie zbudowanych obrazów pod kątem znanych podatności (CVE) za pomocą narzędzi takich jak Trivy, Azure Security Center.
*   **Bezpieczeństwo Jenkins:**
    *   Zabezpiecz dostęp do interfejsu Jenkins (silne hasła, uwierzytelnianie wieloskładnikowe).
    *   Używaj HTTPS (zobacz dodatek poniżej).
    *   Zarządzaj uprawnieniami użytkowników w Jenkins (zasada najmniejszych uprawnień).
    *   Zabezpiecz komunikację między masterem a agentami.
    *   Regularnie aktualizuj Jenkinsa i pluginy.

## 🚧 TODO / Przyszłe Ulepszenia

*   [ ] **Ansible:** Dopracować `universal_setup.yml`, dodać role, obsłużyć różne dystrybucje/wersje.
*   [ ] **Packer:** Dodać więcej przykładów obrazów, zaimplementować wersjonowanie obrazów w nazwach/tagach, dodać skanowanie podatności.
*   [ ] **Jenkins:** Lepsza obsługa błędów i raportowanie, powiadomienia o nieudanych buildach, rozważenie użycia agentów w kontenerach.
*   [ ] **Terraform:** Bardziej elastyczna konfiguracja sieci (np. wybór VNet/Subnet), możliwość użycia Azure Bastion, opcja statycznego prywatnego IP.
*   [ ] **Bezpieczeństwo:** Zaostrzenie reguł NSG jako parametr, bezpieczniejsza dystrybucja danych dostępowych, bardziej granularne role RBAC dla SPN.
*   [ ] **Testowanie:** Dodanie testów (np. Terratest dla Terraform, InSpec/Goss dla obrazów Packer).
*   [ ] **Dokumentacja:** Stworzenie szczegółowych przewodników konfiguracji (Azure RBAC, Jenkins, Key Vault).
*   [ ] **Interfejs Użytkownika:** Rozważenie prostego interfejsu webowego (np. opartego o Rundeck lub prostą aplikację Flask/Django) jako alternatywy dla Jenkins UI dla mniej technicznych użytkowników.
*   [ ] **Monitoring:** Implementacja logowania zdarzeń i monitorowania użycia zasobów.

## 📚 Status projektu

Projekt jest funkcjonalny w zakresie podstawowych operacji (create, destroy, start, stop, restart, auto-cleanup) dla obrazów Marketplace i niestandardowych (Packer). Wymaga jednak dalszych prac nad bezpieczeństwem, obsługą błędów, testowaniem i dokumentacją, zanim będzie można go uznać za gotowy do użycia w środowiskach produkcyjnych lub wymagających wysokiego poziomu bezpieczeństwa.

## 👨‍💻 Autor

**Rafał Poławski**

---

<details>
<summary><strong>Dodatek: Konfiguracja HTTPS dla Jenkinsa z Nginx i Let's Encrypt</strong></summary>

Ta sekcja opisuje, jak zabezpieczyć dostęp do interfejsu Jenkins za pomocą HTTPS, używając Nginx jako reverse proxy i darmowych certyfikatów Let's Encrypt. Jest to krok **zdecydowanie zalecany** dla każdej instancji Jenkins dostępnej z zewnątrz.

**Wymagania:**
*   Działająca instancja Jenkins (np. na porcie 8080).
*   Serwer z publicznym adresem IP.
*   Zainstalowany Nginx (`sudo apt install nginx`).
*   Domena lub subdomena wskazująca na publiczny IP serwera Jenkins.

**Kroki:**

1.  **Konfiguracja DNS:**
    *   Upewnij się, że Twoja domena (np. `jenkins.twojadomena.com`) ma rekord A wskazujący na publiczny adres IP serwera Jenkins.
    *   Sprawdź propagację DNS: `nslookup jenkins.twojadomena.com`. Powinien zwrócić poprawny IP. Czasami propagacja może zająć od kilku minut do kilku godzin.

2.  **Instalacja Certbot (Narzędzie Let's Encrypt):**
    ```bash
    # Dla systemów bazujących na Debian/Ubuntu
    sudo apt update
    sudo apt install certbot python3-certbot-nginx -y
    ```

3.  **Konfiguracja Firewalla:**
    *   Zezwól na ruch HTTP (port 80) i HTTPS (port 443). Certbot używa portu 80 do weryfikacji domeny podczas początkowego uzyskiwania certyfikatu.
    ```bash
    # Przykład dla UFW
    sudo ufw allow 'Nginx Full'
    sudo ufw reload
    # Lub bardziej szczegółowo:
    # sudo ufw allow 80/tcp
    # sudo ufw allow 443/tcp
    # sudo ufw reload
    ```

4.  **Konfiguracja Nginx jako Reverse Proxy (początkowa):**
    *   Utwórz plik konfiguracyjny Nginx dla Jenkinsa, np. `/etc/nginx/sites-available/jenkins`:
      ```nginx
      server {
          listen 80;
          server_name jenkins.twojadomena.com; # <<< ZASTĄP SWOJĄ DOMENĄ

          # Ta sekcja jest ważna, aby Certbot mógł umieścić pliki weryfikacyjne
          location /.well-known/acme-challenge/ {
              root /var/www/html; # Domyślny katalog web Nginx/Apache na Ubuntu/Debian
              allow all;
          }

          # Początkowo blokujemy dostęp lub nie robimy nic z resztą ruchu na porcie 80
          # Certbot sam doda przekierowanie na HTTPS po uzyskaniu certyfikatu.
          location / {
              # return 404; # Można tymczasowo zablokować
              # Lub po prostu zostaw pusty, Certbot zajmie się tym
          }
      }
      ```
    *   Utwórz link symboliczny, aby aktywować konfigurację:
      ```bash
      sudo ln -s /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
      ```
    *   Sprawdź składnię konfiguracji Nginx: `sudo nginx -t`. Jeśli zgłasza błąd `server_names_hash_bucket_size`, edytuj `/etc/nginx/nginx.conf` i w sekcji `http { ... }` dodaj lub odkomentuj `server_names_hash_bucket_size 64;` (lub 128) i ponownie sprawdź składnię.
    *   Zrestartuj Nginx, aby zastosować zmiany: `sudo systemctl restart nginx`

5.  **Uzyskanie Certyfikatu SSL/TLS z Let's Encrypt:**
    *   Uruchom Certbot dla Nginx, podając swoją domenę:
      ```bash
      sudo certbot --nginx -d jenkins.twojadomena.com # <<< ZASTĄP SWOJĄ DOMENĄ
      ```
    *   Postępuj zgodnie z instrukcjami na ekranie:
        *   Podaj adres email (dla powiadomień o wygasaniu).
        *   Zaakceptuj warunki usługi (Terms of Service).
        *   Opcjonalnie zdecyduj, czy chcesz udostępnić swój email EFF.
    *   Certbot wykryje konfigurację w Nginx i zapyta, czy ma automatycznie skonfigurować HTTPS. Wybierz opcję **2: Redirect** - spowoduje to przekierowanie całego ruchu HTTP na HTTPS.
    *   Jeśli wszystko pójdzie pomyślnie, Certbot uzyska certyfikat, zainstaluje go w Nginx i zmodyfikuje plik konfiguracyjny `/etc/nginx/sites-available/jenkins`, dodając sekcję `listen 443 ssl;` oraz odpowiednie dyrektywy `ssl_certificate`, `ssl_certificate_key` i przekierowanie 301 w sekcji `listen 80;`.

6.  **Weryfikacja Automatycznego Odnawiania Certyfikatu:**
    *   Certbot automatycznie konfiguruje zadanie systemowe (cron job lub systemd timer) do odnawiania certyfikatów przed ich wygaśnięciem.
    *   Możesz przetestować mechanizm odnawiania (bez faktycznego odnawiania, jeśli certyfikat jest ważny):
      ```bash
      sudo certbot renew --dry-run
      ```
    *   Możesz sprawdzić status timera (jeśli system używa systemd):
      ```bash
      sudo systemctl status certbot.timer
      ```

7.  **Aktualizacja Adresu URL w Jenkinsie:**
    *   Teraz powinieneś móc uzyskać dostęp do Jenkinsa przez `https://jenkins.twojadomena.com`.
    *   Zaloguj się do Jenkinsa.
    *   Przejdź do **Zarządzanie Jenkins (Manage Jenkins) → Konfiguracja Systemu (Configure System)**.
    *   Znajdź sekcję **Jenkins Location**.
    *   W polu **Jenkins URL** wpisz pełny adres HTTPS: `https://jenkins.twojadomena.com/` (ważny jest `/` na końcu).
    *   Zapisz konfigurację.

**Przykładowa finalna konfiguracja Nginx (po działaniu Certbota, z dodanymi ustawieniami reverse proxy dla Jenkinsa):**
```nginx
server {
    listen 80;
    server_name jenkins.twojadomena.com; # <<< ZASTĄP SWOJĄ DOMENĄ

    # Sekcja dla Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Przekierowanie HTTP na HTTPS dodane przez Certbot
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2; # Włącz HTTP/2 dla lepszej wydajności
    server_name jenkins.twojadomena.com; # <<< ZASTĄP SWOJĄ DOMENĄ

    # --- Konfiguracja SSL dodana/zmodyfikowana przez Certbot ---
    ssl_certificate /etc/letsencrypt/live/jenkins.twojadomena.com/fullchain.pem; # Ścieżka może się różnić
    ssl_certificate_key /etc/letsencrypt/live/jenkins.twojadomena.com/privkey.pem; # Ścieżka może się różnić
    include /etc/letsencrypt/options-ssl-nginx.conf; # Zalecane ustawienia SSL od Certbota
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # Plik z parametrami Diffie-Hellmana
    # ---------------------------------------------------------

    # Ustawienia buforowania i timeoutów dla stabilności
    proxy_buffers 16 64k;
    proxy_buffer_size 128k;
    proxy_read_timeout 90s; # Zwiększony timeout dla długich operacji Jenkins
    proxy_send_timeout 90s;

    location / {
        # Przekierowanie ruchu do Jenkinsa działającego lokalnie na porcie 8080
        proxy_pass http://localhost:8080;

        # Przekazanie nagłówków niezbędnych dla reverse proxy
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme; # Ważne, aby Jenkins wiedział, że połączenie jest przez HTTPS

        # Ustawienia dla WebSocket (ważne dla niektórych funkcji Jenkins UI, np. logów na żywo)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Zapobiegaj buforowaniu odpowiedzi przez Nginx, co może psuć interaktywne elementy Jenkinsa
        proxy_request_buffering off;
        proxy_buffering off; # Czasem potrzebne, jeśli request_buffering off nie wystarcza

        # Przepisanie odpowiedzi redirect z Jenkinsa (jeśli używa wewnętrznego URL)
        proxy_redirect http://localhost:8080 https://jenkins.twojadomena.com;
    }
}