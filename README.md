# 🛠️ Automatyczne wdrażanie maszyn wirtualnych w Azure z wykorzystaniem IaC i Jenkins

## 📌 Opis projektu

Celem projektu jest stworzenie systemu umożliwiającego **automatyczne wdrażanie maszyn wirtualnych w chmurze Azure** na potrzeby laboratoriów lub środowisk testowych, z wykorzystaniem podejścia **Infrastructure as Code (IaC)** oraz procesu **CI/CD**.

Projekt bazuje na takich narzędziach jak:
- **Terraform** – do definiowania i zarządzania infrastrukturą w chmurze Azure,
- **Packer** – do tworzenia prekonfigurowanych obrazów maszyn wirtualnych,
- **Jenkins** – do automatyzacji procesu wdrażania,
- **Ansible** – do konfiguracji systemów po stronie VM (opcjonalnie),
- **Git** – jako system kontroli wersji.

## 🔧 Technologie

- Terraform
- Packer (opcjonalnie)
- Jenkins
- Ansible (opcjonalnie)
- Microsoft Azure
- Bash
- Azure CLI

## 🎯 Główne funkcjonalności

- Automatyczne tworzenie VM na podstawie plików `.tf`,
- Wykorzystanie obrazów przygotowanych w Packerze,
- Po każdej zmianie w repozytorium nowy build w Jenkins już z niego korzysta,
- Wsparcie dla wielu użytkowników dzięki odseparowaniu sesji,
- Automatyczne usuwanie zasobów po określonym czasie działania (lifecycle management),
- Bezpieczne przechowywanie plików stanu Terraform (Azure Storage Account backend).

## 📁 Struktura repozytorium

```
├── ansible/                 # (opcjonalnie) role i playbooki do konfiguracji VM
├── packer/                  # Konfiguracje Packer do budowy obrazów VM
├── terraform/               # Pliki .tf – definicja infrastruktury
├── Jenkinsfile              # Pipeline as Code (Jenkinsfile)
├── .gitignore               # Wykluczony plik z credentials do obrazów budowanych poprzez Packer
└── README.md                # Ten plik
```

## 🚀 Wymagania wstępne

- Płatne konto w Microsoft Azure, może być też trial, ale jest ograniczenie do maksymalnie 6 rdzeni łącznie na subskrypcję dla maszyn wirtualnych.
- Zainstalowane: Terraform, Packer, Jenkins, Git
- Podstawowa znajomość sieci i infrastruktury chmurowej

## 📚 Status projektu

Projekt w trakcie rozwoju. Część funkcji znajduje się w fazie testów. Pliki i instrukcje będą stopniowo uzupełniane. Zapewne słabe bezpieczeństwo.

## 👨‍💻 Autor: Rafał Poławski

# Instrukcja: Konfiguracja Jenkins

# Instrukcja: Konfiguracja Kubernetes/Docker

# Instrukcja: Konfiguracja w Azure, RBAC, Service Principal

# Instrukcja: Ustawienie domeny i HTTPS dla Jenkinsa z Let's Encrypt

## 1. Zakup domeny i konfiguracja DNS, certyfikat TLS (opcjonalnie, jako dodatek)
- **Zakup domeny** (np. przez GoDaddy, OVH, itp.).
- **Dodaj rekord A** w panelu DNS swojej domeny, wskazujący na publiczne IP serwera, na którym działa Jenkins.
  - Rekord A: `twojadomena.com → Twoje_publiczne_IP`.

## 2. Instalacja Certbot i wtyczki Nginx
Wykonaj poniższe kroki, aby zainstalować **Certbot** oraz niezbędne wtyczki dla Nginx, które umożliwią generowanie certyfikatu SSL:

```bash
sudo apt update
sudo apt install certbot python3-certbot-nginx
```

## 3. Sprawdzenie, czy DNS już zaciągnął adres IP
Zanim przejdziesz do generowania certyfikatu, upewnij się, że rekord DNS jest poprawnie propagowany. Możesz to zrobić za pomocą `nslookup`:

```bash
nslookup twojadomena.com
```

Jeśli zwróci adres IP serwera, to oznacza, że DNS zostały poprawnie ustawione.

## 4. Odblokowanie portu 80 (HTTP) i 443 (HTTPS) w firewallu
Aby Certbot mógł zweryfikować domenę, musisz mieć otwarte porty **80 (HTTP)** i **443 (HTTPS)**. Wykonaj poniższe komendy:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

## 5. Modyfikacja konfiguracji Nginx (jeśli wymagane)
W przypadku problemów z konfiguracją Nginx, musisz dodać lub zwiększyć wartość `server_names_hash_bucket_size`:

```bash
sudo nano /etc/nginx/nginx.conf
```

W pliku dodaj:

```nginx
http {
    server_names_hash_bucket_size 128;
    ...
}
```

Zapisz zmiany i uruchom ponownie Nginx:

```bash
sudo systemctl restart nginx
```

## 6. Generowanie certyfikatu SSL dla swojej domeny
Teraz możesz wygenerować certyfikat SSL za pomocą Certbota:

```bash
sudo certbot --nginx -d twojadomena.com
```

Podczas procesu Certbot poprosi Cię o zgodę na warunki korzystania z usługi Let's Encrypt. Po udzieleniu zgody, Certbot wygeneruje certyfikat i skonfiguruje Nginx do używania HTTPS.

## 7. Automatyczne odnawianie certyfikatu
Certbot automatycznie ustawia **cron job** do odnawiania certyfikatu co 60 dni, ale aby upewnić się, że usługa jest aktywna, uruchom poniższą komendę:

```bash
sudo systemctl enable certbot.timer
```

## 8. Ustawienie URL w Jenkinsie
Po skonfigurowaniu HTTPS, w Jenkinsie należy zaktualizować **Jenkins URL**:
- Wejdź w **Jenkins → Manage Jenkins → Configure System**.
- W polu **Jenkins URL** wpisz swoją domenę: `https://twojadomena.com`.

## 9. Przykładowa konfiguracja Nginx
Oto przykładowa konfiguracja Nginx, która powinna działać w przypadku Jenkinsa. Zakłada, że Nginx działa na porcie 80 (HTTP) oraz 443 (HTTPS) i wykonuje przekierowanie z HTTP na HTTPS:

```nginx
server {
    listen 80;
    server_name twojadomena.com www.twojadomena.com;
    
    # Weryfikacja certyfikatu (jeśli używasz certbota)
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Przekierowanie z HTTP do HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name twojadomena.com www.twojadomena.com;
    
    ssl_certificate /etc/letsencrypt/live/twojadomena.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/twojadomena.com/privkey.pem;
    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout 10m;
    
    location / {
        proxy_pass http://localhost:8080; # Jenkins działa na porcie 8080
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_request_buffering off;
        proxy_buffering off;
    }
}
```

## Podsumowanie
1. **Zakup domenę** i skonfiguruj DNS.
2. **Zainstaluj Certbota** oraz wtyczki Nginx.
3. **Sprawdź DNS** za pomocą `nslookup`.
4. **Odblokuj porty 80 i 443**.
5. **Zaktualizuj konfigurację Nginx** (jeśli wymagane).
6. **Wygeneruj certyfikat SSL** za pomocą Certbota.
7. **Skonfiguruj automatyczne odnawianie certyfikatu**.
8. **Zaktualizuj URL w Jenkinsie** na swoją domenę.
9. **Zastosuj odpowiednią konfigurację Nginx**.

