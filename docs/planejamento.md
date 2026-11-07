# Planejamento — Desafio Brute Force com Medusa e Kali Linux

## 1. Objetivo

Executar, em ambiente controlado, os exercícios do curso "Criando um ataque de brute force de senhas com Medusa e Kali Linux" (DIO/Santander), usando o Kali Linux contra o Metasploitable 2, produzindo evidências reproduzíveis e um repositório público.

## 2. Escopo

Dentro do escopo:

- Laboratório próprio: Kali `192.168.56.4` e Metasploitable 2 `192.168.56.3` na rede host-only `vboxnet0` (`192.168.56.0/24`)
- Ferramentas: nmap, hydra, ncrack, john, wpscan, patator, medusa, smbclient/enum4linux/smbmap
- Vetores: FTP, SSH, Telnet, formulário web (DVWA), SMB (enumeração, acesso e spraying), credential stuffing, hashes de demonstração e shadow real
- Extras: VNC, PostgreSQL, MySQL, Tomcat Manager, bindshell 1524 e backdoor vsftpd 2.3.4 (CVE-2011-2523)

Fora do escopo:

- Qualquer alvo fora de faixa privada (o script bloqueia, salvo `FORCE=1`)
- Ataques destrutivos, persistência ou exfiltração; upload SMB apenas com `ACTIVE=1` (arquivo marcador)

## 3. Premissas e restrições

- Metasploitable 2 é intencionalmente vulnerável: uso somente no laboratório
- Host `omega-server-local` acessado por SSH com chave (`~/.ssh/id_ed25519_big`)
- Sessão gráfica via RDP (VRDP do VirtualBox) por túnel SSH
- `sudo` no host exige senha do usuário
- A rede NAT Network original (`10.10.10.0/24`) foi substituída por host-only após comportamento assimétrico

## 4. Arquitetura

| Componente | Detalhes |
|---|---|
| Host | `omega-server-local` (192.168.15.4), Ubuntu 26.04.1, 12 vCPU, 30 GB RAM |
| Hypervisor | VirtualBox 7.2.6_Ubuntu |
| Rede do lab | host-only `vboxnet0` — 192.168.56.0/24, host em .1 |
| Kali | 192.168.56.4 — 4 vCPU, 6144 MB, VRDE 13389 (127.0.0.1) |
| Metasploitable 2 | 192.168.56.3 — 1 vCPU, 1024 MB, VRDE 13390 (127.0.0.1) |
| Acesso RDP | Túnel SSH: local 13389/13390 → host 127.0.0.1:13389/13390 |
| Acesso SSH | Túnel SSH: local 22023/22022 → 192.168.56.4:22 / 192.168.56.3:22 |

## 5. Fases

### Fase 1 — Infraestrutura (concluída)

- [x] VirtualBox 7.2.6 + DKMS instalados e validados
- [x] Kali 2026.3 (imagem pronta) registrado e configurado
- [x] Metasploitable 2 criado com disco VMDK extraído
- [x] VRDE habilitado nas duas VMs
- [x] Migração para rede host-only e IPs estáticos (.3 e .4)

### Fase 2 — Acesso remoto (concluída)

- [x] Túnel SSH para as portas VRDE
- [x] Remmina 1.4.43 (Flatpak) instalado
- [x] Túnel SSH para as portas 22 das VMs validado
- [x] SSH habilitado no Kali

### Fase 3 — Validação (concluída)

- [x] Comunicação Kali ↔ Meta (`ping 192.168.56.3`)
- [x] Varredura de portas (22 portas abertas mapeadas)
- [x] Credenciais válidas encontradas por múltiplos vetores
- [x] Script `lab-attacks.sh` executado de ponta a ponta

Detalhes em [ataques.md](ataques.md#resultado-da-execução-final).

### Fase 4 — Execução dos exercícios (concluída)

- [x] Rodar `./lab-attacks.sh all` e arquivar a saída
- [x] Coletar prints (TTY do Kali + console do Meta)
- [x] Revisar logs e montar a tabela final de achados
- [x] Validar ataques extras (VNC, bancos, Tomcat, bindshell, backdoor)

### Fase 5 — Entrega (concluída)

- [x] Relatório final (README do repositório)
- [x] Evidências organizadas por módulo (`evidence/`)
- [x] `run.log` da execução final arquivado
- [x] Repositório público no GitHub

## 6. Mapa do menu do curso

| Item do menu | Módulo do script | Status |
|---|---|---|
| Ambiente com Kali Linux e Metasploitable 2 | infraestrutura | concluído |
| Alcançando a Máquina Vulnerável no Metasploitable 2 | `recon` | validado |
| Criando Arquivos de Usuários e Senhas Comuns | `prep` | validado |
| Criação de Wordlists | `prep` | validado |
| Hydra no Kali Linux | `hydra` | validado |
| Ncrack no Kali Linux | `ncrack` | validado |
| John no Kali Linux | `john` + `bindshell`/`backdoor` | validado |
| WPScan no Kali Linux | `wpscan` | condicional (alvo sem WordPress) |
| Patator no Kali Linux | `patator` | validado (FTP) |
| Ataques de Força Bruta em Formulários de Login Web | `hydra` (DVWA) | validado |
| Utilizando o Medusa para Simular Combinações de Acesso | `medusa` + `db` | validado |
| Password Spraying e Credential Stuffing | `spray` + `hydra` | validado |
| Ataque em Cadeia: Enumeração SMB e Password Spraying | `smb` + `spray` | validado |
| Simulando um Cenário Corporativo Mal Configurado | `smb` + `smb-access` + `spray` | validado |
| Criando uma Lista de Usuários | `prep` | validado |
| Testando o Acesso Utilizando SMBclient | `smb-access` | validado |
| Limitações do Medusa e Dicas Finais | seção de limitações | documentado |
| Encerramento | checklist de evidências | concluído |
| Entendendo o Desafio | README | concluído |
| Extras | `vnc db tomcat bindshell backdoor` | validado |

## 7. Critérios de aceite

- [x] VMs operacionais e acessíveis por RDP
- [x] Comunicação Kali ↔ Metasploitable
- [x] Credenciais válidas encontradas em FTP, SSH, SMB e formulário web
- [x] Script executa de ponta a ponta com logs
- [x] Evidências (prints) para cada item do menu
- [x] Relatório final entregue
- [x] Repositório público com README, scripts, wordlists e evidências

## 8. Riscos e limitações

| Risco | Mitigação |
|---|---|
| Hydra SSH falha por MAC legado do OpenSSH do Meta | Usar Medusa ou Ncrack para SSH |
| Patator SSH falha por hostkey legado (paramiko) | Usar Medusa/Ncrack; FTP do Patator funciona |
| Patator quebra com Python 3.14 (forkserver) | Wrapper `fork` embutido no script |
| smbmap trava com Python 3.14 | `timeout 60` no módulo `smb` |
| WPScan sem WordPress no Meta | Definir `WPSCAN_URL` para um alvo WordPress |
| `rockyou` completo é muito grande | `MAX_WORDS=1000` por padrão |
| vsftpd backdoor instável | Reiniciar o vsftpd via bindshell 1524 antes do exploit |
| Queda de energia no host | IPs estáticos persistem; validar com `ifconfig` após ligar as VMs |
| Spraying pode gerar lockout em ambientes reais | Uso restrito ao laboratório |
| Upload SMB altera o alvo | Desativado por padrão; `ACTIVE=1` para habilitar |

## 9. Próximos passos (opcional)

1. Publicar um WordPress no lab para validar o módulo WPScan
2. Gerar wordlist maior com `crunch`/seclists
3. Adicionar novos módulos (ex.: IRC UnrealIRCd, NFS, r-services)
