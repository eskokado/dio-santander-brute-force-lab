# Resultados — Resumo

Execução final do script `lab-attacks.sh all` em **2026-11-07** contra o
Metasploitable 2 (`192.168.56.3`), run `20261107-093736`. Logs completos em
[`evidence/20261107-093736/`](../evidence/20261107-093736/).

## Achados principais

| Vetor | Ferramenta | Resultado |
|---|---|---|
| FTP (21) | Hydra, Medusa, Ncrack, Patator | `msfadmin:msfadmin` |
| SSH (22) | Medusa, Ncrack | `msfadmin:msfadmin` |
| DVWA (80) | Hydra `http-post-form` | `admin:password` |
| SMB (445) | Medusa `smbnt` (spray) | `msfadmin:msfadmin` com acesso a `ADMIN$` |
| PostgreSQL (5432) | Medusa | `postgres:postgres` |
| MySQL (3306) | Nmap + mysql | root sem senha |
| VNC (5900) | Hydra | senha `password` |
| Tomcat (8180) | Hydra `http-get` | `tomcat:tomcat` no `/manager/html` |
| Bindshell (1524) | `nc` | shell root direto |
| Backdoor vsftpd (6200) | `scripts/vsftpd_backdoor.py` | shell root + leitura do `/etc/shadow` |
| John (hashes demo) | John | `msfadmin:msfadmin`, `user:password`, `admin:secret` (3/3) |
| John (shadow real) | John | `msfadmin:msfadmin`, `sys:batman`, `klog:123456789` (3/7) |

Também foram confirmadas 22 portas abertas no alvo, incluindo serviços legados
como telnet, r-services, NFS, IRC e X11.

## Destaques

- **Cadeia bindshell 1524 → shadow → John:** a porta 1524 entrega um shell root
  sem autenticação; o módulo captura o `/etc/shadow` e quebra hashes MD5-crypt.
- **Cadeia vsftpd 2.3.4 (CVE-2011-2523):** o backdoor é acionado com
  `USER user:)`, abre uma shell root na porta 6200 e permite repetir a captura
  do shadow.
- **Password spraying:** a mesma senha (`msfadmin`) foi aceita em FTP, SSH,
  PostgreSQL e SMB, mostrando o risco de reutilização de credenciais.
- **Ferramentas:** Medusa e Ncrack cobriram SSH, onde Hydra e Patator falharam
  por incompatibilidade com o OpenSSH antigo (MAC/hostkey legados).

## Mitigações resumidas

- Remover credenciais padrão e usar senhas fortes/únicas com MFA.
- Desabilitar serviços legados (telnet, r-services, FTP, VNC exposto) e SMBv1.
- Fechar a porta 1524 e atualizar o vsftpd (CVE-2011-2523).
- Restringir PostgreSQL/MySQL/Tomcat à rede local e remover acessos sem senha.
- Aplicar bloqueio por tentativas e monitorar password spraying.

## Evidências

- [run.log](../evidence/20261107-093736/run.log) — execução completa
- [nmap.txt](../evidence/20261107-093736/nmap.txt) — portas e versões
- [john-shadow.txt](../evidence/20261107-093736/john-shadow.txt) — quebra do shadow
- [backdoor-root.txt](../evidence/20261107-093736/backdoor-root.txt) — pós-exploração vsftpd
- [kali-nmap.png](../images/kali-nmap.png), [kali-resumo-ataques.png](../images/kali-resumo-ataques.png)

Detalhes por ferramenta e comandos em [ataques.md](ataques.md).
