// File: Jenkinsfile
// Główny Jenkinsfile do zarządzania maszynami wirtualnymi studentów (tworzenie, niszczenie, start/stop/restart).
// Wykorzystuje Terraform do zarządzania infrastrukturą Azure i Ansible (opcjonalnie) do konfiguracji Linux.

// Importy niezbędnych klas Java/Groovy
import java.text.Normalizer // Do usuwania diakrytyków z nazw użytkowników
import java.util.regex.Pattern // Do pracy z wyrażeniami regularnymi (usuwanie diakrytyków)
import java.time.Instant // Do pracy z czasem (znacznik zniszczenia)
import java.time.temporal.ChronoUnit // Do operacji na jednostkach czasu

pipeline {
    // TODO: Zmień na agenta z dedykowaną labelką
    agent any // Używa dowolnego dostępnego agenta Jenkins.

    environment {
        // Globalne zmienne środowiskowe dla pipeline
        ADMIN_EMAIL = credentials('ADMIN_EMAIL') // Adres email admina (do wysyłania powiadomień), pobierany z Jenkins Credentials.
        AZURE_KEY_VAULT_NAME = 'myKeyVault20337' // Nazwa Azure Key Vault do przechowywania sekretów (np. kluczy SSH).
        TF_STATE_RG = 'tfstate-rg' // Nazwa grupy zasobów Azure dla przechowywania stanu Terraform.
        TF_STATE_STORAGE_ACCOUNT = 'tfstatestorage20337' // Nazwa konta Azure Storage dla stanu Terraform.
        TF_STATE_CONTAINER = 'tfstate-students' // Nazwa kontenera Blob Storage dla plików stanu Terraform studentów.
    }
    options {
        // Nie wykonuj domyślnego checkout SCM na początku pipeline, robimy to ręcznie w dedykowanym stage.
        skipDefaultCheckout(true)
    }

    parameters {
        // Parametry wejściowe joba Jenkins.
        choice(
            name: 'OS_TYPE',
            choices: ['windows', 'linux'],
            description: 'Wybierz system operacyjny dla VM.'
        )
        choice(
            name: 'IMAGE_NAME',
            choices: [
                // Lista dostępnych obrazów z Azure Marketplace i niestandardowych.
                // Obrazy Windows
                'WindowsServer:2022-datacenter-smalldisk',
                'WindowsServer:2019-datacenter-smalldisk',
                'WindowsServer:2016-datacenter-smalldisk',
                'windows10-pro', // Niestandardowy obraz
                // Obrazy Linux
                'Ubuntu:22.04-lts-gen2',
                'Ubuntu:20.04-lts-gen2',
                'Debian:11-gen2',
                'ubuntu-2404-lts-xfce-xrdp', // Niestandardowy obraz
            ],
            description: 'Wybierz obraz systemu do zainstalowania na VM.'
        )
        choice(
            name: 'ACTION',
            choices: ['create', 'destroy', 'start', 'stop', 'restart'],
            description: 'Wybierz akcję do wykonania na VM.'
        )
        choice(
            name: 'DESTROY_AFTER',
            choices: ['1m', '3m', '15m', '30m', '45m', '1h', '2h', '4h', '8h', '12h', '24h', '48h'],
            description: 'Wybierz czas (od teraz), po którym maszyna ma zostać automatycznie zniszczona przez job czyszczący.'
        )
        // Opcjonalne flagi instalacji oprogramowania (używane przez Ansible na Linux)
        booleanParam(name: 'INSTALL_NGINX', defaultValue: false, description: 'Czy zainstalować Nginx (tylko Linux)?')
        booleanParam(name: 'INSTALL_DOCKER', defaultValue: false, description: 'Czy zainstalować Docker (tylko Linux)?')
        booleanParam(name: 'INSTALL_PYTHON', defaultValue: false, description: 'Czy zainstalować Python 3 (tylko Linux)?')
        booleanParam(name: 'INSTALL_JAVA', defaultValue: false, description: 'Czy zainstalować Java JDK (tylko Linux)?')

        // Parametr ukryty, używany głównie przez job automatycznego czyszczenia do wskazania,
        // dla którego użytkownika ma być wykonana akcja 'destroy'.
        // Wymaga pluginu Jenkins "Hidden Parameter Plugin".
        hidden(name: 'TARGET_USER_ID', defaultValue: '', description: '[Wewnętrzne, Ukryte] ID użytkownika do zniszczenia VM przez job czyszczący.')
    }

    stages {
        // Etap ustalania, dla kogo (ID, email, nazwa, grupa) jest wykonywany ten build.
        // Rozróżnia między standardowym uruchomieniem przez użytkownika a wywołaniem przez job czyszczący (używając TARGET_USER_ID).
        stage('Inicjalizacja zmiennych użytkownika') {
            steps {
                script {
                    def effectiveUserId = ''
                    def effectiveUserEmail = ''
                    def effectiveUserName = ''
                    def effectiveUserGroup = ''

                    // Sprawdź, czy to akcja 'destroy' i czy podano TARGET_USER_ID (pochodzący z joba czyszczącego).
                    if (params.ACTION == 'destroy' && params.TARGET_USER_ID?.trim()) {
                        effectiveUserId = params.TARGET_USER_ID.trim()
                        echo "INFO: Wykonuję akcję 'destroy' dla użytkownika docelowego (TARGET_USER_ID): ${effectiveUserId}"
                        // Użyj zdefiniowanych wartości dla joba czyszczącego
                        effectiveUserEmail = "${effectiveUserId}@auto-cleanup.local" // Adres email 'syntetyczny'
                        effectiveUserName = "AutoCleanup-${effectiveUserId}"        // Nazwa 'syntetyczna'
                        effectiveUserGroup = 'auto_cleanup_job'                   // Grupa 'syntetyczna'
                    } else {
                        // Standardowe uruchomienie przez użytkownika Jenkins.
                        echo "INFO: Wykonuję akcję '${params.ACTION}' dla użytkownika uruchamiającego."
                        // Pobierz dane użytkownika z Jenkins (wymaga pluginu Build User Variables).
                        def buildUserId = env.BUILD_USER_ID?.trim()
                        def buildUserEmail = env.BUILD_USER_EMAIL?.trim()
                        def buildUser = env.BUILD_USER?.trim()
                        def buildUserGroups = env.BUILD_USER_GROUPS?.trim()

                        // Podstawowa walidacja - ID użytkownika jest kluczowe.
                        if (!buildUserId) { error('Brak ID użytkownika (BUILD_USER_ID). Wymagany plugin Build User Variables.') }
                        if (!buildUserEmail) {
                            echo "OSTRZEŻENIE: Brak adresu email użytkownika (BUILD_USER_EMAIL). Używanie fallbacku: ${buildUserId}@jenkins-user.local"
                            buildUserEmail = "${buildUserId}@jenkins-user.local" // Fallback dla emaila
                        }
                        // Użyj danych zalogowanego użytkownika.
                        effectiveUserId = buildUserId
                        effectiveUserEmail = buildUserEmail
                        effectiveUserName = buildUser ?: effectiveUserId // Użyj nazwy użytkownika, jeśli dostępna, inaczej ID.
                        effectiveUserGroup = buildUserGroups ? buildUserGroups.split(',')[0].trim() : 'brak_grupy' // Pierwsza grupa użytkownika lub fallback.
                    }

                    // Ustaw efektywne wartości jako zmienne środowiskowe pipeline.
                    env.USER_ID = effectiveUserId
                    env.USER_EMAIL = effectiveUserEmail
                    env.USER_FULL_NAME = effectiveUserName
                    env.USER_GROUP = effectiveUserGroup
                    // Definiuje unikalną ścieżkę workspace dla użytkownika, aby uniknąć konfliktów.
                    env.USER_WORKSPACE = "${JENKINS_HOME}/workspace/${env.JOB_NAME}/${env.USER_ID}"

                    // Ostateczna weryfikacja, czy mamy User ID.
                    if (!env.USER_ID) { error('Nie udało się ustalić efektywnego ID użytkownika (env.USER_ID).') }

                    // Wyświetl ustalone dane użytkownika.
                    echo """
                    Efektywna konfiguracja użytkownika dla tego uruchomienia:
                      ID:        ${env.USER_ID}
                      Nazwa:     ${env.USER_FULL_NAME}
                      Email:     ${env.USER_EMAIL}
                      Grupa:     ${env.USER_GROUP}
                      Workspace: ${env.USER_WORKSPACE}
                    """.stripIndent()
                }
            }
        }

        // Sprawdza, czy wybrany OS pasuje do typu wybranego obrazu (Windows/Linux).
        stage('Walidacja parametrów OS/Obraz') {
            steps {
                script {
                    echo "Walidacja: OS=${params.OS_TYPE}, Obraz=${params.IMAGE_NAME}"
                    boolean isWindowsImage = params.IMAGE_NAME.toLowerCase().contains('windows')
                    if (params.OS_TYPE == 'windows' && !isWindowsImage) {
                        error("Wybrano system Windows, ale obraz '${params.IMAGE_NAME}' nie wygląda na obraz Windows.")
                    } else if (params.OS_TYPE == 'linux' && isWindowsImage) {
                        error("Wybrano system Linux, ale obraz '${params.IMAGE_NAME}' wygląda na obraz Windows.")
                    }
                    echo 'Walidacja OS/Obraz OK.'
                }
            }
        }

        // Pobiera kod Terraform/Ansible do dedykowanego workspace użytkownika.
        stage('Pobranie kodu źródłowego') {
            steps {
                script {
                    // Upewnij się, że katalog nadrzędny dla workspace istnieje.
                    sh "mkdir -p '${env.USER_WORKSPACE}'"
                }
                // Przełącz się do katalogu workspace użytkownika.
                dir(env.USER_WORKSPACE) {
                    // Usuń zawartość poprzedniego workspace (jeśli istnieje), aby zapewnić czysty stan.
                    deleteDir()
                    echo "Pobieranie kodu źródłowego do ${env.USER_WORKSPACE}..."
                    // Wykonaj checkout kodu z repozytorium SCM skonfigurowanego w jobie Jenkins.
                    checkout scm
                }
            }
        }

        // Generuje parę kluczy SSH (jeśli tworzona jest VM Linux) i zapisuje je w Azure Key Vault.
        stage('Zarządzanie kluczami SSH (Linux Create)') {
            when {
                // Wykonaj tylko jeśli tworzymy (ACTION == 'create') maszynę Linux (OS_TYPE == 'linux').
                allOf {
                    expression { params.ACTION == 'create' }
                    expression { params.OS_TYPE == 'linux' }
                }
            }
            steps {
                // Pracuj w podkatalogu 'terraform' w workspace użytkownika.
                dir("${env.USER_WORKSPACE}/terraform") {
                    script {
                        // Użyj powłoki shell do wykonania operacji na plikach i ssh-keygen.
                        sh """
                            echo "Tworzenie katalogu ssh_keys..."
                            mkdir -p ssh_keys
                            echo "Generowanie kluczy SSH (4096 bit RSA)..."
                            # Wygeneruj klucze bez hasła (-N ""), cicho (-q), w formacie RSA 4096 bit.
                            ssh-keygen -t rsa -b 4096 -C "${env.USER_EMAIL}" -f ssh_keys/id_rsa -N "" -q || error "Nie udało się wygenerować kluczy SSH."
                            echo "Ustawianie uprawnień dla klucza prywatnego..."
                            # Ustaw uprawnienia 600 (tylko właściciel może czytać/pisać) dla klucza prywatnego.
                            chmod 600 ssh_keys/id_rsa || echo "Ostrzeżenie: Nie udało się ustawić uprawnień 600 dla klucza prywatnego."
                            echo "Wygenerowano i przygotowano klucze SSH w ssh_keys/."
                        """
                        // Wczytaj zawartość wygenerowanych kluczy do zmiennych Groovy.
                        def sshPrivateKeyContent = readFile('ssh_keys/id_rsa')
                        def sshPublicKeyContent = readFile('ssh_keys/id_rsa.pub')

                        // Użyj poświadczeń Azure Service Principal.
                        withCredentials([azureServicePrincipal('AZURE_CREDENTIALS')]) {
                            echo "Zapisywanie kluczy SSH w Azure Key Vault (${env.AZURE_KEY_VAULT_NAME})..."
                            // Użyj Azure CLI do zapisania kluczy jako sekrety w Key Vault. Nazwa sekretu zawiera USER_ID.
                            sh """
                                az keyvault secret set --vault-name "${env.AZURE_KEY_VAULT_NAME}" --name "${env.USER_ID}-ssh-private-key" --value '${sshPrivateKeyContent}' --only-show-errors || error "Nie udało się zapisać klucza prywatnego w Key Vault."
                                az keyvault secret set --vault-name "${env.AZURE_KEY_VAULT_NAME}" --name "${env.USER_ID}-ssh-public-key" --value '${sshPublicKeyContent}' --only-show-errors || error "Nie udało się zapisać klucza publicznego w Key Vault."
                            """
                            echo 'Zapisano klucze w Key Vault.'
                        }
                    }
                }
            }
        }

        // Inicjalizuje Terraform, konfigurując zdalny backend w Azure Blob Storage.
        stage('Inicjalizacja Terraform') {
            // Wykonaj tylko dla akcji 'create' lub 'destroy', które wymagają interakcji ze stanem Terraform.
            when { expression { params.ACTION in ['create', 'destroy'] } }
            steps {
                // Pracuj w podkatalogu 'terraform'.
                dir("${env.USER_WORKSPACE}/terraform") {
                    script {
                        echo 'Generowanie konfiguracji backendu Terraform (backend.tf)...'
                        // Utwórz plik backend.tf dynamicznie, używając zmiennych środowiskowych i USER_ID.
                        // Klucz stanu (key) jest specyficzny dla użytkownika, co izoluje stany.
                        writeFile file: 'backend.tf', text: """// Konfiguracja zdalnego stanu Terraform w Azure Blob Storage
                            terraform {
                                backend "azurerm" {
                                    resource_group_name  = "${env.TF_STATE_RG}"
                                    storage_account_name = "${env.TF_STATE_STORAGE_ACCOUNT}"
                                    container_name       = "${env.TF_STATE_CONTAINER}"
                                    key                  = "${env.USER_ID}.tfstate" // Unikalny klucz stanu dla użytkownika
                                }
                            }
                        """
                        // Użyj poświadczeń Azure.
                        withCredentials([azureServicePrincipal('AZURE_CREDENTIALS')]) {
                            // Uruchom terraform init.
                            sh '''
                                echo "Inicjalizacja Terraform ze zdalnym stanem..."
                                # -input=false: nie pytaj o dane wejściowe
                                # -upgrade: zaktualizuj pluginy do najnowszych kompatybilnych wersji
                                # -backend-config: przekaż dane uwierzytelniające do backendu Azure (z poświadczeń Jenkins)
                                terraform init \
                                    -input=false \
                                    -upgrade \
                                    -backend-config="subscription_id=$AZURE_SUBSCRIPTION_ID" \
                                    -backend-config="tenant_id=$AZURE_TENANT_ID" \
                                    -backend-config="client_id=$AZURE_CLIENT_ID" \
                                    -backend-config="client_secret=$AZURE_CLIENT_SECRET" || error "Inicjalizacja Terraform nie powiodła się."
                                echo "Inicjalizacja Terraform zakończona."
                            '''
                        }
                    }
                }
            }
        }

        // Główny etap wykonujący terraform apply (dla create) lub terraform destroy.
        stage('Tworzenie / Niszczenie Infrastruktury (Terraform)') {
            when { expression { params.ACTION in ['create', 'destroy'] } }
            steps {
                dir("${env.USER_WORKSPACE}/terraform") {
                    withCredentials([azureServicePrincipal('AZURE_CREDENTIALS')]) {
                        script {
                            def adminUsername = ''
                            def generatedPassword = ''
                            def sshPublicKeyContent = ''
                            def destroyTimestampUTC = '' // Znacznik czasu automatycznego zniszczenia

                            // Jeśli tworzymy infrastrukturę...
                            if (params.ACTION == 'create') {
                                // Generuj nazwę użytkownika administratora na podstawie nazwy użytkownika Jenkins.
                                def baseUsername = env.USER_FULL_NAME ?: 'studentadmin' // Fallback, jeśli nazwa niedostępna.
                                // Normalizacja: usuń diakrytyki, znaki specjalne, spacje, ogranicz długość.
                                String normalized = Normalizer.normalize(baseUsername, Normalizer.Form.NFD)
                                Pattern pattern = Pattern.compile('\\p{InCombiningDiacriticalMarks}+')
                                String withoutDiacritics = pattern.matcher(normalized).replaceAll('')
                                String transliterated = withoutDiacritics.replace('ł', 'l').replace('Ł', 'L')
                                adminUsername = transliterated.toLowerCase()
                                                    .replaceAll('\\s+', '') // Usuń spacje
                                                    .replaceAll('[^a-z0-9_.-]', '') // Dozwolone znaki
                                                    .replaceAll('^-|-$', '') // Usuń myślniki na początku/końcu
                                if (adminUsername.length() > 20) { adminUsername = adminUsername.substring(0, 20) } // Limit długości
                                if (adminUsername.length() < 1) { adminUsername = 'studentadmin' } // Minimalna długość
                                // Unikaj zastrzeżonych nazw użytkowników.
                                if (adminUsername ==~ /^(root|admin|administrator|user|guest)$/ || adminUsername.contains(' ')) {
                                    adminUsername = "stud${env.USER_ID.take(10)}" // Generuj fallback z ID użytkownika.
                                }
                                echo "Wygenerowany użytkownik admin: ${adminUsername}"

                                // Generuj losowe, bezpieczne hasło dla administratora (głównie dla Windows).
                                try {
                                    // Użyj narzędzia 'pwgen' (musi być dostępne na agencie Jenkins).
                                    generatedPassword = sh(script: 'pwgen -cny -s 16 1', returnStdout: true).trim()
                                    echo 'Wygenerowano hasło przez pwgen.'
                                } catch (Exception e) {
                                    error("Błąd generowania hasła przez pwgen: ${e.message}. Sprawdź dostępność pwgen na agencie.")
                                }
                                if (!generatedPassword) { error('Nie udało się uzyskać hasła od pwgen.') }

                                // Oblicz znacznik czasu automatycznego zniszczenia na podstawie parametru DESTROY_AFTER.
                                try {
                                    // Wyciągnij wartość liczbową i jednostkę (m, h, s) z parametru.
                                    def durationValue = params.DESTROY_AFTER.replaceAll('[^0-9]', '').toInteger()
                                    def unit
                                    if (params.DESTROY_AFTER.endsWith('m')) { unit = ChronoUnit.MINUTES }
                                    else if (params.DESTROY_AFTER.endsWith('h')) { unit = ChronoUnit.HOURS }
                                    else if (params.DESTROY_AFTER.endsWith('s')) { unit = ChronoUnit.SECONDS } // Dodane dla testów np. 1m
                                    else { throw new IllegalArgumentException("Nieznana jednostka czasu w DESTROY_AFTER: ${params.DESTROY_AFTER}") }

                                    if (durationValue > 0) {
                                        def now = Instant.now() // Aktualny czas UTC
                                        def expiryInstant = now.plus(durationValue, unit) // Oblicz czas wygaśnięcia
                                        // Sformatuj czas do ISO 8601 UTC (np. YYYY-MM-DDTHH:MM:SSZ), wymagany przez tag.
                                        destroyTimestampUTC = expiryInstant.truncatedTo(ChronoUnit.SECONDS).toString()
                                        echo "Maszyna zostanie oznaczona do zniszczenia znacznikiem czasu UTC: ${destroyTimestampUTC}"
                                    } else {
                                        error("Wartość DESTROY_AFTER (${params.DESTROY_AFTER}) nie jest dodatnia.")
                                    }
                                } catch (Exception e) {
                                    // Błąd w parsowaniu czasu jest krytyczny, bo mechanizm czyszczenia polega na tym tagu.
                                    error("KRYTYCZNY BŁĄD podczas przetwarzania DESTROY_AFTER ('${params.DESTROY_AFTER}'): ${e.getMessage()}. Nie można kontynuować bez czasu zniszczenia.")
                                }
                                if (!destroyTimestampUTC) {
                                    // Dodatkowe zabezpieczenie.
                                    error('Nie udało się obliczyć znacznika czasu zniszczenia (destroyTimestampUTC).')
                                }
                            } // Koniec bloku if (params.ACTION == 'create')

                            // Jeśli system to Linux, pobierz klucz publiczny SSH.
                            if (params.OS_TYPE == 'linux') {
                                try {
                                    // Najpierw spróbuj pobrać z Key Vault (na wypadek ponownego uruchomienia lub destroy).
                                    echo "Próba pobrania klucza publicznego SSH z Key Vault dla ${env.USER_ID}..."
                                    sshPublicKeyContent = sh(script: "az keyvault secret show --vault-name '${env.AZURE_KEY_VAULT_NAME}' --name '${env.USER_ID}-ssh-public-key' --query value -o tsv", returnStdout: true).trim()
                                    echo 'Pobrano klucz publiczny z Key Vault.'
                                } catch (Exception e) {
                                    // Jeśli nie ma w Key Vault...
                                    echo "INFO: Nie znaleziono klucza publicznego w Key Vault dla ${env.USER_ID}."
                                    // ...i jest to akcja 'create', użyj klucza właśnie wygenerowanego (jeśli istnieje).
                                    if (params.ACTION == 'create' && fileExists('ssh_keys/id_rsa.pub')) {
                                        sshPublicKeyContent = readFile('ssh_keys/id_rsa.pub').trim()
                                        echo 'Użyto lokalnie wygenerowanego klucza publicznego dla Terraform (create).'
                                    // ...a jest to akcja 'destroy', użyj placeholdera (Terraform go potrzebuje, ale nie użyje).
                                    } else if (params.ACTION == 'destroy') {
                                        sshPublicKeyContent = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCplaceholderpublickeyfordestroy' // Dowolny poprawny format klucza
                                        echo 'Użyto placeholdera dla klucza publicznego (destroy).'
                                    } else {
                                        // Inna sytuacja (np. create bez wygenerowanego klucza) jest błędem.
                                        error("Nie można uzyskać klucza publicznego SSH dla ${params.ACTION} Linux.")
                                    }
                                }
                            } else { // Dla Windows klucz SSH nie jest potrzebny.
                                sshPublicKeyContent = 'not-used-for-windows'
                            }
                            // Ostateczny fallback, gdyby zmienna była pusta.
                            if (!sshPublicKeyContent) { sshPublicKeyContent = 'placeholder-key-if-needed' }

                            // Określ komendę Terraform (apply lub destroy).
                            def terraformCommand = params.ACTION == 'create' ? 'apply' : 'destroy'
                            // Przygotuj listę zmiennych do przekazania przez -var.
                            def tfVars = [
                                "os_type=${params.OS_TYPE}",
                                "image_name=${params.IMAGE_NAME}",
                                "user_id=${env.USER_ID}",
                                "destroy_timestamp_utc=${destroyTimestampUTC}" // Przekaż obliczony czas zniszczenia
                            ]
                            // Przekaż zmienne przez środowisko (preferowane dla sekretów).
                            env.TF_VAR_subscription_id = env.AZURE_SUBSCRIPTION_ID // Z poświadczeń Azure
                            env.TF_VAR_ssh_public_key = sshPublicKeyContent // Klucz publiczny lub placeholder

                            // Przekaż dane logowania tylko przy tworzeniu. Użyj placeholderów dla destroy.
                            if (params.ACTION == 'create') {
                                env.TF_VAR_admin_username = adminUsername
                                env.TF_VAR_admin_password = generatedPassword
                            } else {
                                // Terraform wymaga podania tych zmiennych, ale nie użyje ich przy destroy.
                                env.TF_VAR_admin_username = 'unused-destroy'
                                env.TF_VAR_admin_password = 'PlaceholderP@ssw0rdDestroy' // Musi spełniać politykę haseł Azure
                            }
                            // Zbuduj argumenty -var="..." dla pozostałych zmiennych.
                            def varArgs = tfVars.collect { "-var=\"${it}\"" }.join(' ')

                            // Uruchom Terraform apply lub destroy.
                            try {
                                echo "Uruchamianie: terraform ${terraformCommand} ${varArgs}..."
                                // -auto-approve: Pomiń potwierdzenie interaktywne.
                                // -lock-timeout=5m: Ustaw limit czasu oczekiwania na blokadę stanu (jeśli inny proces go trzyma).
                                sh """
                                    terraform ${terraformCommand} -auto-approve -lock-timeout=5m ${varArgs} || error "Polecenie Terraform ${terraformCommand} nie powiodło się."
                                """
                                echo "Terraform ${terraformCommand} zakończony pomyślnie."
                            } finally {
                                // Wyczyść zmienne środowiskowe TF_VAR_* po wykonaniu Terraform, aby uniknąć wycieku.
                                echo 'Czyszczenie zmiennych TF_VAR_*.'
                                env.TF_VAR_subscription_id = null
                                env.TF_VAR_admin_username = null
                                env.TF_VAR_admin_password = null
                                env.TF_VAR_ssh_public_key = null
                            }
                        }
                    }
                }
            }
        }

        // Konfiguruje nowo utworzoną maszynę Linux za pomocą Ansible.
        stage('Konfiguracja systemu (Ansible - Linux Create)') {
            when {
                // Wykonaj tylko jeśli tworzymy (ACTION == 'create') maszynę Linux (OS_TYPE == 'linux').
                allOf {
                    expression { params.ACTION == 'create' }
                    expression { params.OS_TYPE == 'linux' }
                }
            }
            steps {
                // Pracuj w katalogu 'terraform'.
                dir("${env.USER_WORKSPACE}/terraform") {
                    // Krótkie opóźnienie, aby dać VM czas na pełne uruchomienie i dostępność SSH.
                    sleep(time: 5, unit: 'SECONDS')
                    script {
                        // Pobierz dane wyjściowe z Terraform (potrzebujemy IP, nazwy użytkownika).
                        def tfOutput = readJSON(text: sh(script: 'terraform output -json', returnStdout: true).trim())
                        // Walidacja podstawowych danych wyjściowych.
                        if (!tfOutput || !tfOutput.vm_credentials || !tfOutput.vm_credentials.value) {
                            error("Nieprawidłowe dane wyjściowe 'vm_credentials' z Terraform.")
                        }
                        def vmCreds = tfOutput.vm_credentials.value
                        if (!vmCreds.public_ip) { error('Brak public_ip w danych wyjściowych Terraform.') }
                        if (!vmCreds.username) { error('Brak username w danych wyjściowych Terraform.') }

                        // Przygotuj dodatkowe zmienne dla Ansible na podstawie parametrów Jenkins.
                        def extraVars = [:]
                        extraVars.install_nginx = params.INSTALL_NGINX ?: false
                        extraVars.install_docker = params.INSTALL_DOCKER ?: false
                        extraVars.install_python = params.INSTALL_PYTHON ?: false
                        extraVars.install_java = params.INSTALL_JAVA ?: false
                        extraVars.timezone = params.TIMEZONE ?: 'UTC' // Przykład dodatkowej zmiennej (nie ma jej w parametrach, ale można dodać)

                        // Konwertuj mapę Groovy na string JSON dla Ansible (-e).
                        def extraVarsJson = groovy.json.JsonOutput.toJson(extraVars)
                        // Zapisz klucz prywatny do tymczasowego pliku PEM dla Ansible.
                        def keyFile = "ssh_key_${BUILD_NUMBER}.pem" // Unikalna nazwa pliku dla buildu.
                        // Użyj klucza z outputu Terraform (jeśli tam jest) lub z lokalnego pliku.
                        def privateKeyContent = vmCreds.private_key ?: readFile('ssh_keys/id_rsa')
                        writeFile file: keyFile, text: privateKeyContent
                        sh "chmod 600 ${keyFile}" // Ustaw odpowiednie uprawnienia.

                        // Uruchom playbook Ansible.
                        try {
                            echo 'Uruchamianie Ansible playbook...'
                            // ANSIBLE_HOST_KEY_CHECKING=False: Wyłącz sprawdzanie klucza hosta SSH (przydatne przy nowo tworzonych VM).
                            // -i '${vmCreds.public_ip},': Dynamiczny inwentarz zawierający tylko IP naszej VM (przecinek jest ważny!).
                            // -u ${vmCreds.username}: Użytkownik do logowania.
                            // --private-key=${keyFile}: Ścieżka do klucza prywatnego.
                            // -e '${extraVarsJson}': Przekaż dodatkowe zmienne jako JSON.
                            // ../ansible/universal_setup.yml: Ścieżka do playbooka (względem katalogu terraform).
                            sh """
                                ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \\
                                    -i '${vmCreds.public_ip},' \\
                                    -u ${vmCreds.username} \\
                                    --private-key=${keyFile} \\
                                    -e '${extraVarsJson}' \\
                                    ../ansible/universal_setup.yml
                            """
                            echo 'Ansible playbook zakończony.'
                        } catch (Exception e) {
                            // Błąd Ansible nie powinien zatrzymywać całego pipeline, ale oznacz build jako niestabilny.
                            echo "Błąd podczas konfiguracji Ansible: ${e.message}"
                            currentBuild.result = 'UNSTABLE'
                        } finally {
                            // Zawsze usuń tymczasowy plik klucza SSH po zakończeniu Ansible.
                            echo "Usuwanie tymczasowego klucza SSH (${keyFile})."
                            sh "rm -f ${keyFile}"
                        }
                    }
                }
            }
        }

        // Zarządza stanem zasilania istniejącej VM (start, stop, restart) używając Azure CLI.
        stage('Zarządzanie stanem VM (Azure CLI)') {
            // Wykonaj tylko dla akcji 'start', 'stop', 'restart'.
            when { expression { params.ACTION in ['start', 'stop', 'restart'] } }
            steps {
                withCredentials([azureServicePrincipal('AZURE_CREDENTIALS')]) {
                    script {
                        // Logowanie do Azure CLI jest już zazwyczaj obsłużone przez plugin, ale dla pewności.
                        /*
                        sh '''
                            echo "Logowanie do Azure CLI..."
                            az login --service-principal -u "$AZURE_CLIENT_ID" -p "$AZURE_CLIENT_SECRET" -t "$AZURE_TENANT_ID"
                            az account set --subscription "$AZURE_SUBSCRIPTION_ID"
                        '''
                        */
                        echo "Wyszukiwanie VM z tagiem OwnerId=${env.USER_ID}..."
                        // Znajdź VM należącą do użytkownika na podstawie tagu 'OwnerId'.
                        // Zakładamy, że użytkownik ma tylko jedną VM z tym tagiem.
                        def vmInfoJson = sh(script: "az vm list --query \"[?tags.OwnerId == '${env.USER_ID}']\" -o json", returnStdout: true).trim()

                        // Sprawdź, czy znaleziono VM.
                        if (vmInfoJson == '[]') { error("Nie znaleziono VM z tagiem OwnerId=${env.USER_ID}") }
                        // Wybierz pierwszą znalezioną VM.
                        def vm = readJSON(text: vmInfoJson)[0]

                        echo "Wykonywanie akcji '${params.ACTION}' na VM '${vm.name}' w grupie '${vm.resourceGroup}'..."
                        // Wykonaj odpowiednią komendę Azure CLI (start, stop, deallocate, restart).
                        // Dla 'stop' używamy 'deallocate', aby zwolnić zasoby obliczeniowe i zatrzymać naliczanie opłat.
                        // Dla 'restart' można dodać --force, jeśli jest potrzebne.
                        def cliAction = (params.ACTION == 'stop') ? 'deallocate' : params.ACTION
                        sh """
                            az vm ${cliAction} \\
                                --resource-group "${vm.resourceGroup}" \\
                                --name "${vm.name}" \\
                                ${params.ACTION == 'restart' ? '--force' : ''}
                        """
                        echo "Akcja '${cliAction}' zakończona."
                    }
                }
            }
        }

        // Usuwa sekrety kluczy SSH (prywatny i publiczny) z Azure Key Vault podczas niszczenia maszyny Linux.
        stage('Czyszczenie kluczy SSH (Linux Destroy)') {
            when {
                // Wykonaj tylko przy niszczeniu (ACTION == 'destroy') maszyny Linux (OS_TYPE == 'linux').
                allOf {
                    expression { params.ACTION == 'destroy' }
                    expression { params.OS_TYPE == 'linux' }
                }
            }
            steps {
                withCredentials([azureServicePrincipal('AZURE_CREDENTIALS')]) {
                    echo "Usuwanie sekretów kluczy SSH z Azure Key Vault (${env.AZURE_KEY_VAULT_NAME}) dla ${env.USER_ID}..."
                    // Użyj Azure CLI do usunięcia sekretów.
                    sh """
                        echo "Usuwanie sekretu klucza prywatnego..."
                        # Usuń sekret (trafia do 'soft delete'). Ignoruj błędy, jeśli sekret nie istnieje.
                        az keyvault secret delete --vault-name "${env.AZURE_KEY_VAULT_NAME}" --name "${env.USER_ID}-ssh-private-key" --only-show-errors || echo "INFO: Sekret klucza prywatnego ${env.USER_ID}-ssh-private-key nie istnieje lub błąd usuwania."
                        echo "Usuwanie sekretu klucza publicznego..."
                        az keyvault secret delete --vault-name "${env.AZURE_KEY_VAULT_NAME}" --name "${env.USER_ID}-ssh-public-key" --only-show-errors || echo "INFO: Sekret klucza publicznego ${env.USER_ID}-ssh-public-key nie istnieje lub błąd usuwania."

                        # Key Vault wymaga odczekania (domyślnie 7 dni, ale można krócej) przed trwałym usunięciem (purge).
                        # Tutaj czekamy krótko, zakładając, że okres retencji soft-delete jest krótki lub wyłączony (niezalecane produkcyjnie).
                        # W praktyce, purge może wymagać osobnego procesu lub dłuższego oczekiwania.
                        echo "Oczekiwanie 30s na możliwość wyczyszczenia (purge)..."
                        sleep 30

                        echo "Czyszczenie (purge) sekretu klucza prywatnego..."
                        # Trwale usuń sekret. Ignoruj błędy (np. jeśli już wyczyszczony lub okres retencji nie minął).
                        az keyvault secret purge --vault-name "${env.AZURE_KEY_VAULT_NAME}" --name "${env.USER_ID}-ssh-private-key" --only-show-errors || echo "INFO: Sekret ${env.USER_ID}-ssh-private-key nie do wyczyszczenia (nie istnieje, już wyczyszczony lub błąd)."
                        echo "Czyszczenie (purge) sekretu klucza publicznego..."
                        az keyvault secret purge --vault-name "${env.AZURE_KEY_VAULT_NAME}" --name "${env.USER_ID}-ssh-public-key" --only-show-errors || echo "INFO: Sekret ${env.USER_ID}-ssh-public-key nie do wyczyszczenia (nie istnieje, już wyczyszczony lub błąd)."
                    """
                    echo 'Zakończono próbę czyszczenia kluczy SSH z Key Vault.'
                }
            }
        }

        // Wysyła email do użytkownika z danymi dostępowymi do nowo utworzonej VM.
        stage('Wysyłanie danych dostępowych (Create)') {
            when { expression { params.ACTION == 'create' } } // Tylko przy tworzeniu.
            steps {
                dir("${env.USER_WORKSPACE}/terraform") { // Pracuj w katalogu terraform.
                    script {
                        // Pobierz dane wyjściowe z Terraform (IP, użytkownik, hasło/klucz).
                        def tfOutput = readJSON(text: sh(script: 'terraform output -json', returnStdout: true).trim())
                        // Podstawowa walidacja outputu.
                        if (!tfOutput?.vm_credentials?.value) { error("Brak lub nieprawidłowe dane 'vm_credentials' w output Terraform.") }
                        def vmCreds = tfOutput.vm_credentials.value

                        if (!vmCreds.public_ip) { error('Brak public_ip w vm_credentials.') }
                        if (!vmCreds.username) { error('Brak username w vm_credentials.') }

                        // Wywołaj odpowiednią funkcję pomocniczą w zależności od systemu operacyjnego.
                        if (params.OS_TYPE == 'linux') {
                            // Sprawdź, czy plik klucza prywatnego istnieje lokalnie (powinien po stage'u generowania).
                            if (!fileExists('ssh_keys/id_rsa')) { error('Brak pliku klucza ssh_keys/id_rsa do wysłania.') }
                            sendLinuxAccessData(vmCreds) // Wywołaj funkcję dla Linux.
                        } else { // Windows
                            // Sprawdź, czy hasło jest dostępne w danych wyjściowych.
                            if (!vmCreds.password) { error('Brak password w vm_credentials dla Windows.') }
                            sendWindowsAccessData(vmCreds) // Wywołaj funkcję dla Windows.
                        }
                    }
                }
            }
        }
    } // Koniec sekcji stages

    post {
        // Sekcja wykonywana zawsze na końcu pipeline, niezależnie od wyniku.
        always {
            script {
                echo "Czyszczenie workspace: ${env.USER_WORKSPACE}"
                // Sprawdź, czy zmienne potrzebne do ścieżki workspace są ustawione.
                if (env.USER_WORKSPACE && env.USER_ID) {
                    def wsPath = env.USER_WORKSPACE
                    // Użyj skryptu powłoki do usunięcia katalogu workspace użytkownika oraz powiązanych katalogów tymczasowych Jenkinsa.
                    sh """
                        #!/bin/bash
                        WORKSPACE_PATH="${wsPath}"
                        echo "Sprawdzanie istnienia katalogu: \${WORKSPACE_PATH}"
                        if [ -d "\${WORKSPACE_PATH}" ]; then
                            echo "Usuwanie katalogu i powiązanych katalogów Jenkinsa: \${WORKSPACE_PATH}..."
                            # Usuń główny workspace oraz katalogi @tmp, @script, @libs powiązane z nim.
                            rm -rf "\${WORKSPACE_PATH}" "\${WORKSPACE_PATH}@tmp" "\${WORKSPACE_PATH}@script" "\${WORKSPACE_PATH}@libs"
                            # Sprawdź kod powrotu rm.
                            if [ \$? -ne 0 ]; then
                                echo "Ostrzeżenie: Nie udało się całkowicie usunąć workspace \${WORKSPACE_PATH}. Mogą istnieć zablokowane pliki lub problemy z uprawnieniami."
                            else
                                echo "Workspace \${WORKSPACE_PATH} usunięty pomyślnie."
                            fi
                        else
                            echo "Katalog workspace \${WORKSPACE_PATH} nie istnieje lub został już usunięty."
                        fi
                    """
                } else {
                    // Komunikat, jeśli nie można określić ścieżki do czyszczenia.
                    echo "Zmienna USER_WORKSPACE ('${env.USER_WORKSPACE}') lub USER_ID ('${env.USER_ID}') nie jest poprawnie ustawiona, pomijanie czyszczenia workspace."
                }
            }
        }
    } // Koniec sekcji post
} // Koniec pipeline

// --- Funkcje Pomocnicze ---

// Wysyła dane dostępowe dla maszyny Linux (dwa emaile: jeden z ZIPem, drugi z hasłem).
def sendLinuxAccessData(vmCreds) {
    // Konwertuj klucz PEM na format PPK dla PuTTY (wymaga puttygen na agencie).
    try {
        sh 'puttygen ssh_keys/id_rsa -o ssh_keys/id_rsa.ppk -O private'
    } catch (Exception e) { error("Nie udało się skonwertować klucza do PPK: ${e.message}") }

    // Wygeneruj silne, losowe hasło do archiwum ZIP (wymaga openssl na agencie).
    def zipPassword = ''
    try {
        zipPassword = sh(script: 'openssl rand -base64 20 | tr -dc "a-zA-Z0-9@#%^" | head -c 16', returnStdout: true).trim()
        if (!zipPassword) { error('Nie udało się wygenerować hasła do ZIP.') }
    } catch (Exception e) { error("Błąd podczas generowania hasła do ZIP: ${e.message}") }

    // Utwórz zaszyfrowane archiwum ZIP zawierające klucze PEM i PPK (wymaga zip na agencie).
    try {
        sh """
            echo "Tworzenie archiwum ZIP z kluczami..."
            # -j: nie zapisuj ścieżek, -P: ustaw hasło
            zip -j -P "${zipPassword}" ssh_keys/ssh_keys.zip \\
                ssh_keys/id_rsa \\
                ssh_keys/id_rsa.ppk
        """
    } catch (Exception e) { error("Nie udało się utworzyć archiwum ZIP: ${e.message}") }

    // Wyślij pierwszy email z załączonym archiwum ZIP.
    try {
        echo "Wysyłanie emaila z kluczami dla ${env.USER_EMAIL}..."
        emailext(
            subject: '[Student Labs] Maszyna Linux gotowa (Klucz SSH)', // Poprawiony temat
            body: """Witaj ${env.USER_FULL_NAME},

Twoja maszyna wirtualna Linux jest gotowa.

Dane dostępowe:
IP: ${vmCreds.public_ip}
Użytkownik: ${vmCreds.username}

W załączniku znajduje się archiwum ZIP ('ssh_keys.zip') zawierające Twój prywatny klucz SSH w formatach PEM (dla OpenSSH) i PPK (dla PuTTY).

Hasło do tego archiwum otrzymasz w **osobnej wiadomości email**.

Pozdrawiamy,
Zespół Administracji Student Labs""".stripIndent(),
            to: env.USER_EMAIL,
            from: env.ADMIN_EMAIL,
            attachmentsPattern: 'ssh_keys/ssh_keys.zip' // Ścieżka do załącznika
        )
    } catch (Exception e) {
        echo "BŁĄD: Wysyłanie emaila z kluczami nie powiodło się: ${e.message}"
        currentBuild.result = 'UNSTABLE' // Oznacz build jako niestabilny
    }

    // Wyślij drugi email z hasłem do ZIPa i instrukcjami połączenia.
    try {
        echo "Wysyłanie emaila z hasłem i instrukcją dla ${env.USER_EMAIL}..."
        emailext(
            subject: '[Student Labs] Hasło do klucza SSH i instrukcja połączenia (Linux)', // Poprawiony temat
            body: """Witaj ${env.USER_FULL_NAME},

Oto hasło do archiwum ZIP ('ssh_keys.zip') z Twoim kluczem SSH, które otrzymałeś/aś w poprzednim emailu:
${zipPassword}

Dane dostępowe przypomnienie:
IP: ${vmCreds.public_ip}
Użytkownik: ${vmCreds.username}

Instrukcje połączenia:
================ Linux/Mac/WSL (terminal z OpenSSH) ===============
1. Wypakuj archiwum 'ssh_keys.zip' używając powyższego hasła. Znajdziesz tam plik 'id_rsa'.
2. Otwórz terminal i przejdź do katalogu, gdzie wypakowałeś/aś pliki.
3. Ustaw odpowiednie uprawnienia dla klucza: chmod 600 id_rsa
4. Połącz się używając komendy: ssh -i id_rsa ${vmCreds.username}@${vmCreds.public_ip}

================ Windows (PuTTY) =======================
1. Wypakuj archiwum 'ssh_keys.zip' używając powyższego hasła. Znajdziesz tam plik 'id_rsa.ppk'.
2. Otwórz aplikację PuTTY.
3. W sekcji 'Session', w polu 'Host Name (or IP address)' wpisz: ${vmCreds.public_ip}
4. W drzewie po lewej stronie przejdź do 'Connection' > 'SSH' > 'Auth' > 'Credentials'.
5. Kliknij przycisk 'Browse...' obok pola 'Private key file for authentication' i wskaż wypakowany plik 'id_rsa.ppk'.
6. Kliknij przycisk 'Open' na dole okna PuTTY.
7. W oknie terminala, które się pojawi, zaloguj się jako użytkownik: ${vmCreds.username}

Ważne: Traktuj swój klucz prywatny ('id_rsa' / 'id_rsa.ppk') jak hasło - nie udostępniaj go nikomu!

Pozdrawiamy,
Zespół Administracji Student Labs""".stripIndent(),
            to: env.USER_EMAIL,
            from: env.ADMIN_EMAIL
        )
    } catch (Exception e) {
        echo "BŁĄD: Wysyłanie emaila z instrukcją nie powiodło się: ${e.message}"
        currentBuild.result = 'UNSTABLE'
    } finally {
        // Zawsze usuń tymczasowe pliki (ZIP i PPK) po próbie wysłania emaili.
        echo 'Czyszczenie tymczasowych plików kluczy (zip, ppk)...'
        sh 'rm -f ssh_keys/ssh_keys.zip ssh_keys/id_rsa.ppk || true' // Ignoruj błędy, jeśli pliki nie istnieją.
    }
    }

// Wysyła dane dostępowe dla maszyny Windows (jeden email z hasłem i plikiem RDP).
def sendWindowsAccessData(vmCreds) {
    // Wygeneruj zawartość pliku RDP z podstawowymi ustawieniami.
    def rdpContent = """
        full address:s:${vmCreds.public_ip}
        username:s:${vmCreds.username}
        prompt for credentials:i:0
        administrative session:i:1
        authentication level:i:2
        use redirection server name:i:0
        disable wallpaper:i:1
        disable full window drag:i:1
        disable menu anims:i:1
        disable themes:i:0
        disable cursor setting:i:0
        bitmapcachepersistenable:i:1
        screen mode id:i:2
        session bpp:i:32
        connect to console:i:0
        redirectclipboard:i:1
        compression:i:1
        autoreconnection enabled:i:1
        smart sizing:i:1
        displayconnectionbar:i:1
    """.stripIndent()

    // Zapisz zawartość do tymczasowego pliku RDP.
    try {
        writeFile file: 'vm_connection.rdp', text: rdpContent
    } catch (Exception e) { error("Nie udało się utworzyć pliku RDP: ${e.message}") }

    // Wyślij email z danymi logowania i załączonym plikiem RDP.
    try {
        echo "Wysyłanie emaila z danymi dostępowymi Windows dla ${env.USER_EMAIL}..."
        emailext(
            subject: '[Student Labs] Maszyna Windows gotowa', // Poprawiony temat
            body: """Witaj ${env.USER_FULL_NAME},

Twoja maszyna wirtualna Windows jest gotowa.

Dane dostępowe:
Adres IP: ${vmCreds.public_ip}
Login: ${vmCreds.username}
Hasło: ${vmCreds.password}

Instrukcje połączenia:
1. Pobierz i otwórz załączony plik 'vm_connection.rdp'.
2. Gdy pojawi się monit o poświadczenia, użyj powyższego loginu i hasła.

Alternatywnie, możesz użyć standardowego klienta Podłączania pulpitu zdalnego (Remote Desktop Connection / mstsc.exe) i ręcznie wpisać adres IP oraz dane logowania.

Ważne: Ze względów bezpieczeństwa, **zmień hasło administratora** po pierwszym zalogowaniu się do maszyny!

Pozdrawiamy,
Zespół Administracji Student Labs""".stripIndent(),
            to: env.USER_EMAIL,
            from: env.ADMIN_EMAIL,
            attachmentsPattern: 'vm_connection.rdp' // Ścieżka do załącznika
        )
    } catch (Exception e) {
        echo "BŁĄD: Wysyłanie emaila dla Windows nie powiodło się: ${e.message}"
        currentBuild.result = 'UNSTABLE'
    } finally {
        // Zawsze usuń tymczasowy plik RDP po próbie wysłania emaila.
        echo 'Czyszczenie pliku RDP...'
        sh 'rm -f vm_connection.rdp || true' // Ignoruj błędy.
    }
    }
