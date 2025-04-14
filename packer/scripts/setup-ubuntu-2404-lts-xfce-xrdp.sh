# File: packer/scripts/setup-ubuntu-2404-lts-xfce-xrdp.sh
#!/bin/bash -e
# Opis: Skrypt provisioningu dla obrazu Packer Ubuntu 24.04 LTS z XFCE i XRDP.
#       Instaluje środowisko graficzne XFCE, serwer zdalnego pulpitu XRDP,
#       konfiguruje je do współpracy i wykonuje podstawowe utwardzanie.
#       Wywoływany przez Packer z uprawnieniami root (poprzez sudo).
# Opcja -e: Skrypt zakończy działanie natychmiast, jeśli jakakolwiek komenda zwróci błąd.

# Odczytaj nazwę użytkownika administracyjnego (tworzonego przez Azure/Packer)
# z pierwszego argumentu przekazanego do skryptu przez Packer.
# Jest to potrzebne do ustawienia własności plików konfiguracyjnych w katalogu domowym.
ADMIN_USERNAME="$1"

echo "=== Rozpoczęcie provisioningu GUI dla Ubuntu 24.04 XFCE/XRDP ==="

# Sprawdzenie przekazanych zmiennych środowiskowych i argumentów
echo "Zmienna DEBIAN_FRONTEND: ${DEBIAN_FRONTEND}" # Powinna być 'noninteractive'
echo "Odebrany argument ADMIN_USERNAME: ${ADMIN_USERNAME}"

# Sprawdź, czy nazwa użytkownika została przekazana.
if [ -z "$ADMIN_USERNAME" ]; then
  echo "BŁĄD KRYTYCZNY: Nie przekazano argumentu ADMIN_USERNAME do skryptu!"
  exit 1
fi

# Upewnij się, że DEBIAN_FRONTEND jest ustawione, aby uniknąć interaktywnych promptów
# podczas instalacji pakietów (apt-get).
export DEBIAN_FRONTEND=noninteractive

# Czekaj na zwolnienie blokad apt, które mogą być trzymane przez procesy
# takie jak cloud-init lub unattended-upgrades tuż po starcie VM.
echo "==> Czekanie na odblokowanie menedżera pakietów apt..."
while fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock* >/dev/null 2>&1; do
  echo 'Czekam na zwolnienie blokady apt (procesy w tle mogą aktualizować system)...'
  sleep 10
done
echo "==> Blokada apt zwolniona."

# Aktualizacja systemu
echo "==> Aktualizacja listy pakietów (apt-get update)"
apt-get update -qq # -qq = cichy tryb

echo "==> Aktualizacja zainstalowanych pakietów (apt-get upgrade)"
# Użyj opcji Dpkg, aby automatycznie obsługiwać konflikty plików konfiguracyjnych,
# preferując wersje domyślne (--force-confdef) lub istniejące (--force-confold).
apt-get upgrade -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Instalacja środowiska graficznego XFCE, serwera XRDP i powiązanych narzędzi.
echo "==> Instalacja XFCE, XRDP i niezbędnych narzędzi"
# xfce4 - metapakiet XFCE
# xfce4-goodies - zestaw przydatnych dodatków do XFCE
# xrdp - serwer RDP
# dbus-x11 - wymagany do poprawnej komunikacji między procesami w sesji graficznej (często rozwiązuje problemy z uprawnieniami)
apt-get install -y -qq xfce4 xfce4-goodies xrdp dbus-x11

# Opcjonalnie: Instalacja dodatkowego oprogramowania graficznego
# echo "==> Instalacja GIMP (opcjonalnie - odkomentuj, jeśli potrzebne)"
# apt-get install -y -qq gimp

# Konfiguracja sesji XRDP, aby używała XFCE.
echo "==> Konfiguracja sesji XRDP dla XFCE"
# Ustaw XFCE jako domyślną sesję dla nowo tworzonych użytkowników (w pliku wzorcowym /etc/skel).
echo "xfce4-session" >/etc/skel/.xsession
# Ustaw XFCE jako domyślną sesję dla użytkownika admina (tego, który został przekazany jako $1).
# Plik .xsession w katalogu domowym użytkownika ma pierwszeństwo przed /etc/xrdp/startwm.sh.
ADMIN_HOME="/home/${ADMIN_USERNAME}"
if [ -d "$ADMIN_HOME" ]; then
  echo "Ustawianie sesji XFCE dla użytkownika ${ADMIN_USERNAME} w ${ADMIN_HOME}/.xsession"
  echo "xfce4-session" >"${ADMIN_HOME}/.xsession"
  # Ustaw poprawne prawa własności dla pliku.
  chown "${ADMIN_USERNAME}:${ADMIN_USERNAME}" "${ADMIN_HOME}/.xsession"
else
  # Ostrzeżenie, jeśli katalog domowy nie istnieje (co nie powinno się zdarzyć).
  echo "OSTRZEŻENIE: Nie znaleziono katalogu domowego ${ADMIN_HOME} dla użytkownika ${ADMIN_USERNAME}!"
fi

# Konfiguracja PolicyKit dla XRDP, aby umożliwić użytkownikom zdalnym wykonywanie
# pewnych akcji systemowych (np. zarządzanie kolorami, siecią, montowanie dysków),
# które mogą być domyślnie zablokowane w sesji zdalnej.
echo "==> Konfiguracja PolicyKit dla XRDP (uprawnienia)"
# Utwórz katalog na lokalne reguły PolicyKit (-p tworzy nadrzędne i ignoruje błąd, jeśli istnieje).
mkdir -p /etc/polkit-1/localauthority/50-local.d/

# Utwórz plik konfiguracyjny .pkla z regułami zezwalającymi na typowe operacje.
cat >/etc/polkit-1/localauthority/50-local.d/46-allow-xrdp-user-operations.pkla <<EOF
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes

[Allow NetworkManager all Users]
Identity=unix-user:*
Action=org.freedesktop.NetworkManager.settings.modify.system;org.freedesktop.NetworkManager.network-control
ResultAny=no
ResultInactive=no
ResultActive=yes

[Allow UDisks2 all Users]
Identity=unix-user:*
Action=org.freedesktop.udisks2.filesystem-mount-system
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

# Włączenie usługi XRDP, aby startowała automatycznie przy uruchomieniu systemu.
echo "==> Włączenie usługi XRDP (start przy bootowaniu)"
systemctl enable xrdp

# Podstawowe utwardzanie (Hardening) systemu.
echo "==> Podstawowe utwardzanie systemu"

# Konfiguracja UFW (Uncomplicated Firewall).
echo "  -> Konfiguracja firewalla UFW"
apt-get install -y -qq ufw
ufw allow ssh      # Zezwól na standardowy port SSH (22/tcp).
ufw allow 3389/tcp # Zezwól na standardowy port RDP (3389/tcp) dla XRDP.
# Poniższe linie są opcjonalne, ale zalecane dla zwiększenia bezpieczeństwa.
# ufw default deny incoming # Domyślnie blokuj cały ruch przychodzący.
# ufw default allow outgoing # Domyślnie zezwalaj na cały ruch wychodzący.
echo "y" | ufw enable # Włącz UFW, automatycznie odpowiadając 'yes' na pytanie.
ufw status verbose    # Wyświetl status i reguły firewalla.

# Konfiguracja SSH dla zwiększenia bezpieczeństwa.
echo "  -> Utwardzanie konfiguracji serwera SSH"
# Utwórz plik konfiguracyjny w /etc/ssh/sshd_config.d/, aby nadpisać domyślne ustawienia.
cat >/etc/ssh/sshd_config.d/90-hardening.conf <<EOF
# Wyłącz możliwość logowania jako użytkownik root przez SSH.
PermitRootLogin no

# Wymagaj logowania tylko za pomocą kluczy SSH (wyłącz logowanie hasłem).
# To jest kluczowe dla bezpieczeństwa w chmurze.
PasswordAuthentication no
ChallengeResponseAuthentication no
# Jeśli używasz tylko kluczy, można rozważyć wyłączenie PAM dla sshd,
# chociaż może to wpłynąć na inne funkcje (np. bannery). Pozostawienie 'yes' jest bezpieczniejsze.
# UsePAM no # Odkomentuj ostrożnie

# Używaj tylko bezpieczniejszego protokołu SSH w wersji 2.
Protocol 2
EOF
# Niektóre wersje sshd mogą wymagać istnienia tego katalogu przed testem konfiguracji.
echo "  -> Tworzenie katalogu /run/sshd dla privilege separation (jeśli nie istnieje)"
mkdir -p /run/sshd
chmod 0755 /run/sshd
# Sprawdź poprawność składni konfiguracji SSH *przed* restartem usługi.
echo "  -> Testowanie konfiguracji SSH poleceniem 'sshd -t'"
sshd -t || (
  echo "KRYTYCZNY BŁĄD: Konfiguracja SSH (/etc/ssh/sshd_config*) jest niepoprawna!"
  exit 1
)
# Zastosuj zmiany poprzez restart usługi SSH.
echo "  -> Restartowanie usługi ssh.service"
# Traktuj błąd restartu jako niekrytyczny (exit 0) dla buildu Packer,
# ponieważ może być spowodowany chwilowymi problemami sieciowymi w środowisku budowy,
# a konfiguracja została już zweryfikowana. Finalny test statusu i tak to sprawdzi.
systemctl restart ssh.service || (
  echo "OSTRZEŻENIE: Nie udało się zrestartować ssh.service. Kontynuowanie buildu..."
  exit 0
)

# Ostateczne sprawdzenie statusu kluczowych usług po konfiguracji.
echo "==> Sprawdzenie statusu kluczowych usług (XRDP, SSH, UFW)"
systemctl is-active xrdp || (
  echo "BŁĄD KRYTYCZNY: Usługa XRDP (xrdp.service) nie jest aktywna!"
  exit 1
)
systemctl is-active ssh.service || (
  echo "BŁĄD KRYTYCZNY: Usługa SSH (ssh.service) nie jest aktywna po restarcie!"
  exit 1
)
ufw status | grep -q 'Status: active' || (
  echo "BŁĄD KRYTYCZNY: Firewall UFW nie jest aktywny!"
  exit 1
)
echo "==> Kluczowe usługi są aktywne."

# Czyszczenie systemu przed finalizacją obrazu.
echo "==> Czyszczenie systemu (usuwanie zbędnych pakietów, cache, historii)"
apt-get autoremove -y -qq   # Usuń pakiety, które nie są już potrzebne jako zależności.
apt-get clean               # Wyczyść lokalne repozytorium pobranych plików pakietów (/var/cache/apt/archives).
rm -rf /var/lib/apt/lists/* # Usuń pobrane listy pakietów.
# Usuń historię poleceń powłoki dla użytkownika root i użytkownika admina.
echo "  -> Czyszczenie historii Bash..."
rm -f /root/.bash_history
[ -f "${ADMIN_HOME}/.bash_history" ] && rm -f "${ADMIN_HOME}/.bash_history"
echo "==> Czyszczenie zakończone."

echo "=== Zakończono provisioning GUI dla Ubuntu 24.04 XFCE/XRDP ==="
