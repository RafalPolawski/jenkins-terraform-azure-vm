pipeline {
    agent any
        
    environment {
        ADMIN_EMAIL = credentials('ADMIN_EMAIL')
    }
    options {
        skipDefaultCheckout(true)
        buildDiscarder(logRotator(
            numToKeepStr: '100',
            artifactNumToKeepStr: '100'
        ))
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['create', 'destroy', 'start', 'stop', 'restart'],
            description: 'Wybierz akcję do wykonania'
        )
        choice(
            name: 'OS_TYPE',
            choices: ['windows', 'linux'],
            description: 'Wybierz system operacyjny'
        )
        choice(
            name: 'IMAGE_NAME',
            choices: [
                // Obrazy Windows
                'WindowsServer:2022-datacenter-smalldisk',
                'WindowsServer:2019-datacenter-smalldisk',
                'WindowsServer:2016-datacenter-smalldisk',
                'windows10-edu',
                // Obrazy Linux
                'Ubuntu:22.04-lts-gen2',
                'Ubuntu:20.04-lts-gen2',
                'Debian:11-gen2',
                'ubuntu-gimp-gui',
            ],
            description: 'Wybierz obraz systemu'
        )
        choice(
            name: 'DESTROY_AFTER',
            choices: ['3m', '15m', '30m', '45m', '1h', '2h', '4h', '8h', '12h', '24h', '48h'],
            description: 'Wybierz czas, po którym maszyna ma zostać zniszczona'
        )
        // Parametry boolowskie dla instalacji dodatkowych komponentów poprzez Ansible
        booleanParam(
            name: 'INSTALL_NGINX',
            defaultValue: false,
            description: 'Czy zainstalować Nginx? (Tylko dla Linux)'
        )
        booleanParam(
            name: 'INSTALL_DOCKER',
            defaultValue: false,
            description: 'Czy zainstalować Docker? (Tylko dla Linux)'
        )
        booleanParam(
            name: 'INSTALL_PYTHON',
            defaultValue: false,
            description: 'Czy zainstalować Python 3? (Tylko dla Linux)'
        )
        booleanParam(
            name: 'INSTALL_JAVA',
            defaultValue: false,
            description: 'Czy zainstalować Java JDK? (Tylko dla Linux)'
        )
    } 
           
    stages {
        // Inicjalizacja zmiennych środowiskowych
        stage('Inicjalizacja zmniennych użytkownika') {
            steps {
                script {
                    // Używamy zmiennych dostarczonych przez Build User Variables plugin
                    env.USER_ID = env.BUILD_USER_ID ?: 'Unknown'
                    env.USER_FULL_NAME = env.BUILD_USER ?: 'Unknown'
                    env.USER_EMAIL = env.BUILD_USER_EMAIL ?: 'unknown@example.com'
                    env.USER_GROUP = env.BUILD_USER_GROUPS ? env.BUILD_USER_GROUPS.split(',')[0] : 'unknown'
                    
                    // Ustawiamy dedykowany workspace dla użytkownika
                    env.USER_WORKSPACE = "${JENKINS_HOME}/workspace/${env.JOB_NAME}/${env.USER_ID}"
                    
                    echo "Inicjalizacja zmiennych dla: ${env.USER_FULL_NAME} (${env.USER_ID}, ${env.USER_EMAIL})"
                    echo "Dedykowany workspace: ${env.USER_WORKSPACE}"
                }
            }
        }

        // Pobranie kodu źródłowego z GitHub (wymagana konfiguracja SCM w Jenkinsie)
        stage('Pobranie kodu źródłowego') {
            steps {
                dir(env.USER_WORKSPACE) {
                    checkout scm
                }
            }
        }
        
        // Generowanie kluczy SSH (tylko dla systemów linux)
        stage('Zarządzanie kluczami SSH') {
            when { 
                allOf {
                    expression { params.ACTION == 'create' }
                    expression { params.OS_TYPE == 'linux' }
                }
            }
            steps {
                dir("${env.USER_WORKSPACE}/terraform") {
                    script {
                        // Generuj klucze SSH
                        sh """
                            mkdir -p ssh_keys
                            ssh-keygen -t rsa -b 4096 -C "${env.USER_EMAIL}" -f ssh_keys/id_rsa -N ""
                        """
                        
                        // Zapisz klucze w zmiennych
                        env.SSH_PRIVATE_KEY = readFile('ssh_keys/id_rsa')
                        env.SSH_PUBLIC_KEY = readFile('ssh_keys/id_rsa.pub')
                        
                        // Zapisz klucze w Azure Key Vault
                        withCredentials([azureServicePrincipal('AZURE_CREDENTIALS')]) {
                            sh """
                                az keyvault secret set --vault-name "myKeyVault20337" --name "${env.USER_ID}-ssh-private-key" --value "${env.SSH_PRIVATE_KEY}"
                                az keyvault secret set --vault-name "myKeyVault20337" --name "${env.USER_ID}-ssh-public-key" --value "${env.SSH_PUBLIC_KEY}"
                            """
                        }
                    }
                }
            }
        }
        
        // Konfiguracja i inicjalizacja Terraform (wymagane utworzenie storage account(unikalna nazwa) i kontenera w Azure)
        stage('Pobranie lub utworzenie pliku stanu, inicjalizacja Terraform') {
            when { expression { params.ACTION in ['create', 'destroy'] } }
            steps {
                dir("${env.USER_WORKSPACE}/terraform") {
                    script {
                        // Konfiguracja pliku stanu
                        writeFile file: 'backend.tf', text: """
                            terraform {
                                backend "azurerm" {
                                    resource_group_name  = "tfstate-rg"
                                    storage_account_name = "tfstatestorage20337"
                                    container_name       = "tfstate-students"
                                    key                  = "${env.USER_ID}.tfstate"
                                }
                            }
                        """
                        
                        // Inicjalizacja Terraform
                        withCredentials([azureServicePrincipal('AZURE_CREDENTIALS')]) {
                            sh '''
                                terraform init \
                                    -input=false \
                                    -backend-config="subscription_id=$AZURE_SUBSCRIPTION_ID" \
                                    -backend-config="tenant_id=$AZURE_TENANT_ID" \
                                    -backend-config="client_id=$AZURE_CLIENT_ID" \
                                    -backend-config="client_secret=$AZURE_CLIENT_SECRET"
                            '''
                        }
                    }
                }
            }
        }
        
        // Zarządzanie infrastrukturą
        // Przebudować bo są tu dziury w zabezpieczeniach, np. hasło admina jest jawne w kodzie, ale to do Windows, który mnie nie interesuje na razie.
        // Coś jest nie tak z przekazaniem id subskrypcji, dlatego ten string nie wiadomo po co, do naprawy.
        stage('Towrzenie oraz niszczenie infrastruktury') {
            when { expression { params.ACTION in ['create', 'destroy'] } }
            steps {
                dir("${env.USER_WORKSPACE}/terraform") {
                    withCredentials([
                        azureServicePrincipal('AZURE_CREDENTIALS'),
                        string(credentialsId: 'AZURE_SUBSCRIPTION_ID', variable: 'AZURE_SUBSCRIPTION_ID')
                    ]) {
                        script {
                            // Pobierz klucze SSH z Key Vault (dla Linux)
                            def sshPublicKey = ''
                            def sshPrivateKey = ''
                            
                            if (params.OS_TYPE == 'linux') {
                                sshPublicKey = sh(
                                    script: "az keyvault secret show --vault-name 'myKeyVault20337' --name '${env.USER_ID}-ssh-public-key' --query value -o tsv",
                                    returnStdout: true
                                ).trim()
                                
                                sshPrivateKey = sh(
                                    script: "az keyvault secret show --vault-name 'myKeyVault20337' --name '${env.USER_ID}-ssh-private-key' --query value -o tsv",
                                    returnStdout: true
                                ).trim()
                            }
                            
                            // Wykonaj odpowiednią operację Terraform
                            def terraformCommand = params.ACTION == 'create' ? 'apply' : 'destroy'
                            
                            sh """
                                export TF_VAR_subscription_id=${AZURE_SUBSCRIPTION_ID}
                                terraform ${terraformCommand} -auto-approve \
                                    -var="os_type=${params.OS_TYPE}" \
                                    -var="image_name=${params.IMAGE_NAME}" \
                                    -var="admin_username=studentadmin" \
                                    -var="admin_password=StudentPassword123!" \
                                    -var="user_id=${env.USER_ID}" \
                                    -var="ssh_public_key=${sshPublicKey}" \
                                    -var="ssh_private_key=${sshPrivateKey}"
                            """
                        }
                    }
                }
            }
        }

        // Instalacja dodatkowego oprogramowania (tylko dla Linux)
        stage('Konfiguracja systemu poprzez Ansible') {
            when { 
                allOf {
                    expression { params.ACTION == 'create' }
                    expression { params.OS_TYPE == 'linux' }
                }
            }
            steps {
                dir("${env.USER_WORKSPACE}/terraform") {
                    sleep(time: 5, unit: 'SECONDS')
                    script {
                        // Pobierz dane wyjściowe z Terraform
                        def tfOutput = readJSON(text: sh(script: 'terraform output -json', returnStdout: true).trim())
                        def vmCreds = tfOutput.vm_credentials.value
                        
                        // Przygotuj zmienne Ansible na podstawie parametrów
                        def extraVars = [:]
                        extraVars.install_nginx = params.INSTALL_NGINX ?: false
                        extraVars.install_docker = params.INSTALL_DOCKER ?: false
                        extraVars.install_python = params.INSTALL_PYTHON ?: false
                        extraVars.install_java = params.INSTALL_JAVA ?: false
                        
                        // Dodaj dodatkowe zmienne konfiguracyjne
                        extraVars.timezone = params.TIMEZONE ?: "UTC"
                        
                        // Konwersja mapy do formatu JSON dla Ansible
                        def extraVarsJson = groovy.json.JsonOutput.toJson(extraVars)
                        
                        // Tworzymy tymczasowy klucz SSH
                        def keyFile = "ssh_key_${BUILD_NUMBER}.pem"
                        writeFile file: keyFile, text: vmCreds.private_key ?: readFile('ssh_keys/id_rsa')
                        sh "chmod 600 ${keyFile}"
                        
                        try {
                            // Wykonaj playbook Ansible bezpośrednio z parametrami, bez inventory
                            sh """
                                ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
                                    -i '${vmCreds.public_ip},' \
                                    -u ${vmCreds.username} \
                                    --private-key=${keyFile} \
                                    -e '${extraVarsJson}' \
                                    ../ansible/universal_setup.yml
                            """
                        } catch (Exception e) {
                            echo "Wystąpił błąd podczas konfiguracji systemu: ${e.message}"
                            currentBuild.result = 'UNSTABLE'
                        } finally {
                            // Usuń tymczasowy klucz
                            sh "rm -f ${keyFile}"
                        }
                    }
                }
            }
        }

        // Zarządzanie stanem VM poprzez Azure CLI (start/stop/restart)
        stage('Zarządzanie stanem VM') {
            when { expression { params.ACTION in ['start', 'stop', 'restart'] } }
            steps {
                withCredentials([azureServicePrincipal('AZURE_CREDENTIALS')]) {
                    script {
                        // Logowanie do Azure CLI
                        sh '''
                            az login --service-principal -u "$AZURE_CLIENT_ID" -p "$AZURE_CLIENT_SECRET" -t "$AZURE_TENANT_ID"
                            az account set --subscription "$AZURE_SUBSCRIPTION_ID"
                        '''
                        
                        // Wyszukaj VM po tagu OwnerId
                        def vmInfo = sh(
                            script: "az vm list --query \"[?tags.OwnerId == '${env.USER_ID}']\" -o json", 
                            returnStdout: true
                        ).trim()
                        
                        if (vmInfo == "[]") {
                            error("Nie znaleziono maszyny z tagiem OwnerId=${env.USER_ID}")
                        }
                        
                        def vm = readJSON(text: vmInfo)[0]
                        
                        // Wykonaj akcję na VM
                        sh """
                            az vm ${params.ACTION} \
                                --resource-group "${vm.resourceGroup}" \
                                --name "${vm.name}" \
                                ${params.ACTION == 'restart' ? '--force' : ''}
                        """
                    }
                }
            }
        }

        // Usuwanie kluczy SSH po zniszczeniu maszyny
        stage('Czyszczenie kluczy SSH') {
            when { 
                allOf {
                    expression { params.ACTION == 'destroy' }
                    expression { params.OS_TYPE == 'linux' }
                }
            }
            steps {
                withCredentials([azureServicePrincipal('AZURE_CREDENTIALS')]) {
                    sh """
                        az keyvault secret delete --vault-name "myKeyVault20337" --name "${env.USER_ID}-ssh-private-key"
                        az keyvault secret delete --vault-name "myKeyVault20337" --name "${env.USER_ID}-ssh-public-key"
                        sleep 10
                        az keyvault secret purge --vault-name "myKeyVault20337" --name "${env.USER_ID}-ssh-private-key" || true
                        az keyvault secret purge --vault-name "myKeyVault20337" --name "${env.USER_ID}-ssh-public-key" || true
                    """
                }
            }
        }

        // Wysyłanie danych dostępowych
        stage('Wysyłanie danych dostępowych') {
            when { 
                expression { params.ACTION == 'create' }
            }
            steps {
                dir("${env.USER_WORKSPACE}/terraform") {
                    script {
                        // Pobierz dane wyjściowe z Terraform
                        def tfOutput = readJSON(text: sh(script: 'terraform output -json', returnStdout: true).trim())
                        def vmCreds = tfOutput.vm_credentials.value
                        
                        if (!vmCreds.public_ip) {
                            error("Brak adresu IP w danych wyjściowych Terraform")
                        }
                        
                        if (params.OS_TYPE == 'linux') {
                            sendLinuxAccessData(vmCreds)
                        } else {
                            sendWindowsAccessData(vmCreds)
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                // Zaplanuj niszczenie maszyny, jeśli ustawiono timer
                if (params.ACTION == 'create' && params.DESTROY_AFTER) {
                    def destroyAfterSeconds = 0
                    if (params.DESTROY_AFTER.endsWith('m')) {
                        destroyAfterSeconds = params.DESTROY_AFTER.replaceAll('m', '').toInteger() * 60
                    } else if (params.DESTROY_AFTER.endsWith('h')) {
                        destroyAfterSeconds = params.DESTROY_AFTER.replaceAll('h', '').toInteger() * 3600
                    }

                    echo "Maszyna zostanie zniszczona po ${params.DESTROY_AFTER} (${destroyAfterSeconds} sekundach)."
                    
                    sleep(time: destroyAfterSeconds, unit: 'SECONDS')
                    
                    echo "Rozpoczynanie procesu niszczenia maszyny..."
                    build(
                        job: env.JOB_NAME,
                        parameters: [
                            string(name: 'ACTION', value: 'destroy'),
                            string(name: 'OS_TYPE', value: params.OS_TYPE),
                            string(name: 'IMAGE_NAME', value: params.IMAGE_NAME),
                            string(name: 'DESTROY_AFTER', value: params.DESTROY_AFTER)
                        ],
                        wait: false
                    )
                }
            }
        }
        always {
            script {
                // Czyszczenie workspace użytkownika
                echo "Czyszczenie workspace dla użytkownika: ${env.USER_ID}"
                sh """
                    if [ -d "${env.USER_WORKSPACE}" ]; then
                        rm -rf "${env.USER_WORKSPACE}" "${env.USER_WORKSPACE}@tmp"
                        echo "Usunięto katalog: ${env.USER_WORKSPACE}"
                    else
                        echo "Katalog nie istnieje: ${env.USER_WORKSPACE}"
                    fi
                """
            }
        }
    }
}

// Funkcja pomocnicza do wysyłania danych dostępowych dla Linux
def sendLinuxAccessData(vmCreds) {
    // Konwersja klucza do formatu PPK
    sh """
        puttygen ssh_keys/id_rsa -o ssh_keys/id_rsa.ppk -O private
    """

    // Generowanie losowego hasła
    def password = sh(
        script: 'openssl rand -base64 20 | tr -dc "a-zA-Z0-9@#%^" | head -c 16',
        returnStdout: true
    ).trim()

    // Przygotowanie zaszyfrowanego ZIP z kluczem SSH
    sh """
        zip -j -P "${password}" ssh_keys/ssh_keys.zip \
            ssh_keys/id_rsa \
            ssh_keys/id_rsa.ppk
    """

    // Email: archiwum z kluczem
    emailext(
        subject: "Maszyna Linux gotowa (archiwum z kluczem prywatnym)",
        body: """
            Witaj ${env.USER_FULL_NAME},
            
            Dane dostępowe do maszyny Linux:
            IP: ${vmCreds.public_ip}
            Użytkownik: ${vmCreds.username}
            
            W załączniku znajduje się archiwum z kluczami SSH w formatach:
            - PEM (dla OpenSSH/Linux/Mac)
            - PPK (dla Putty/Windows)
            
            Hasło do paczki oraz instrukcję połączenia otrzymasz w osobnej wiadomości.
            
            Pozdrawiamy,
            Zespół Administracji
        """.stripIndent(),
        to: env.USER_EMAIL,
        from: env.ADMIN_EMAIL,
        attachmentsPattern: 'ssh_keys/ssh_keys.zip'
    )

    // Email z hasłem i instrukcją do podłączenia
    emailext(
        subject: "Instrukcja połączenia z maszyną Linux (klucz SSH)",
        body: """
            Witaj ${env.USER_FULL_NAME},
            
            Oto hasło do archiwum z kluczem SSH:
            ${password}
            
            Instrukcja wypakowania kluczy:
            1. Pobierz załącznik 'ssh_keys.zip' z poprzedniego maila
            2. Wypakuj archiwum i użyj hasła do odszyfrowania kluczy
            
            Dane dostępowe do maszyny Linux:
            IP: ${vmCreds.public_ip}
            Użytkownik: ${vmCreds.username}

            Instrukcje połączenia:

            ======================================================
               Dla Linux/Mac/WSL/Windows (PowerShell z OpenSSH) 
            ======================================================
            
            0. Jeżeli masz zainstalowany unzip (Linux/Mac) lub 7-Zip (Windows)
            unzip -P "${password}" ssh_keys.zip
            1. Otwórz terminal i przejdź do katalogu z kluczami
            2. Połącz się komendą:
            ssh -i id_rsa ${vmCreds.username}@${vmCreds.public_ip}

            =====================================================
                             Dla Windows (PuTTY)
            =====================================================
            
            1. Pobierz i zainstaluj PuTTY: https://www.putty.org/
            2. Otwórz PuTTY i wprowadź:
            Host Name: ${vmCreds.public_ip}
            Port: 22
            3. W sekcji Connection > SSH > Auth > Credentials:
            - Wskaż ścieżkę do pliku id_rsa.ppk
            4. Kliknij 'Open' i zaloguj się jako: ${vmCreds.username}

            Bezpieczeństwo:
            - Klucz SSH jest równoznaczny z hasłem do systemu
            - Nie udostępniaj go osobom postronnym
            - Zalecana zmiana klucza po pierwszym logowaniu
            
            Pozdrawiamy,
            Zespół Administracji
        """.stripIndent(),
        to: env.USER_EMAIL,
        from: env.ADMIN_EMAIL
    )

    // Czyszczenie tymczasowych plików
    sh "rm -f ssh_keys/ssh_keys.zip ssh_keys/id_rsa.ppk"
}

// Funkcja pomocnicza do wysyłania danych dostępowych dla Windows
def sendWindowsAccessData(vmCreds) {
    // Tworzenie pliku RDP
    writeFile file: "vm_connection.rdp", text: """
full address:s:${vmCreds.public_ip}
username:s:${vmCreds.username}
prompt for credentials:i:0
administrative session:i:1
authentication level:i:2
use redirection server name:i:0
alternate shell:s:
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
redirectprinters:i:0
compression:i:1
autoreconnection enabled:i:1
smart sizing:i:1
prompt for credentials on client:i:0
displayconnectionbar:i:1
    """

    // Wysłanie maila z załącznikiem - plikiem RDP
    emailext(
        subject: "Maszyna Windows gotowa",
        body: """
            Witaj ${env.USER_FULL_NAME},
            
            Dane dostępowe do maszyny Windows:
            IP: ${vmCreds.public_ip}
            Login: ${vmCreds.username}
            Hasło: ${vmCreds.password}
            
            Instrukcje:
            1. Otwórz załączony plik VM_connection.rdp
            2. Klient Remote Desktop zapyta o poświadczenia
            3. Wprowadź login i hasło z tego maila
            
            Alternatywnie:
            1. Użyj Remote Desktop Connection (mstsc)
            2. Wprowadź IP: ${vmCreds.public_ip}
            3. Zaloguj się używając danych powyżej
            
            Bezpieczeństwo:
            - Nie udostępniaj danych logowania
            - Zalecana zmiana hasła po pierwszym logowaniu
            
            Pozdrawiamy,
            Zespół Administracji
        """.stripIndent(),
        to: env.USER_EMAIL,
        from: env.ADMIN_EMAIL,
        attachmentsPattern: 'vm_connection.rdp'
    )
}