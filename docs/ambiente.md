# Ambiente do Laboratório

## Host

- Nome: `omega-server-local` (192.168.15.4)
- SO: Ubuntu 26.04.1, 12 vCPU, 30 GB RAM, VT-x + `/dev/kvm`
- VirtualBox: 7.2.6_Ubuntu (módulos `vboxdrv`, `vboxnetflt`, `vboxnetadp` carregados)
- Usuário: `eskokado` (grupo `vboxusers`)
- Acesso:

```bash
ssh -i ~/.ssh/id_ed25519_big eskokado@192.168.15.4
```

## Rede

- Host-only: `vboxnet0` — `192.168.56.0/24`, host `192.168.56.1`
- Kali: `192.168.56.4` (estático) e NAT para internet
- Metasploitable 2: `192.168.56.3` (estático)
- A rede NAT Network original (`LabNet`, 10.10.10.0/24) foi removida por apresentar
  comportamento assimétrico (Kali → Meta falhava, Meta → Kali funcionava)
- Não há port forwards; o SSH às VMs é feito por túnel através do host (veja Acesso)

## VMs

### Kali Linux

| Item | Valor |
|---|---|
| Nome no VirtualBox | `kali-linux-2026.3-virtualbox-amd64` |
| Imagem | Kali 2026.3 VirtualBox (imagem pronta) |
| Recursos | 4 vCPU, 6144 MB |
| Disco | VDI ~16,8 GB |
| Rede | `nic1` host-only `vboxnet0` — 192.168.56.4/24 (estático); `nic2` NAT (internet) |
| VRDE | `127.0.0.1:13389`, auth null |
| Credenciais | `kali` / `kali` |
| Guest Additions | 7.2.16 (`VBoxManage guestcontrol` funciona) |
| SSH | habilitado (`sshd` ativo) |

### Metasploitable 2

| Item | Valor |
|---|---|
| Nome no VirtualBox | `Metasploitable 2` |
| Imagem | `Metasploitable.vmdk` (VMware convertida) |
| Recursos | 1 vCPU, 1024 MB |
| Controladora | SCSI LsiLogic, portcount 16 |
| Rede | host-only `vboxnet0` — 192.168.56.3/24 (estático em `/etc/network/interfaces`) |
| VRDE | `127.0.0.1:13390`, auth null |
| Credenciais | `msfadmin` / `msfadmin` |

## Acesso

### RDP via Remmina (sessão gráfica)

Túnel SSH (executar na máquina local e manter aberto):

```bash
ssh -i ~/.ssh/id_ed25519_big -N \
  -L 13389:127.0.0.1:13389 \
  -L 13390:127.0.0.1:13390 \
  eskokado@192.168.15.4
```

Cliente:

```bash
flatpak run org.remmina.Remmina
```

| VM | Endereço no Remmina | Credenciais |
|---|---|---|
| Kali | `localhost:13389` | `kali` / `kali` |
| Metasploitable 2 | `localhost:13390` | `msfadmin` / `msfadmin` |

### SSH

As VMs estão na rede host-only, acessível apenas pelo host. Use um túnel SSH
para expor as portas 22:

```bash
ssh -i ~/.ssh/id_ed25519_big -N \
  -L 22022:192.168.56.3:22 \
  -L 22023:192.168.56.4:22 \
  eskokado@192.168.15.4
```

Em outro terminal:

```bash
ssh -p 22023 kali@localhost        # Kali
ssh -p 22022 msfadmin@localhost    # Metasploitable 2
```

Dentro do laboratório (a partir do Kali):

```bash
ssh msfadmin@192.168.56.3
```

## Operação

Iniciar as VMs (no host):

```bash
VBoxManage startvm "kali-linux-2026.3-virtualbox-amd64" --type headless
VBoxManage startvm "Metasploitable 2" --type headless
```

Desligar:

```bash
VBoxManage controlvm "kali-linux-2026.3-virtualbox-amd64" acpipowerbutton
VBoxManage controlvm "Metasploitable 2" acpipowerbutton
```

Túnel RDP (máquina local):

```bash
ssh -i ~/.ssh/id_ed25519_big -N \
  -L 13389:127.0.0.1:13389 \
  -L 13390:127.0.0.1:13390 \
  eskokado@192.168.15.4
```

## Troubleshooting

### ExtPack VNC quebrado

O ExtPack VNC do repositório Ubuntu está com placeholder de versão (`@VBOX_VERSION_STRING_RAW@`) e não carrega. Solução adotada: usar o VRDP (RDP nativo) do VirtualBox, acessível pelo Remmina.

### Hydra/Patator via SSH falham

O OpenSSH do Metasploitable 2 é antigo e só oferece MACs/hostkeys legados:

- Hydra: `kex error ... no match for method mac`
- Patator: `paramiko ... Incompatible ssh peer (no acceptable host key)`

Use **Medusa** ou **Ncrack** para SSH; Hydra e Patator funcionam normalmente em FTP/Telnet/formulário.

### Patator e Python 3.14

O Kali 2026.3 usa Python 3.14, cujo `multiprocessing` usa `forkserver` por padrão e quebra o Patator. O script já embute o workaround:

```bash
python3 -c 'import multiprocessing as mp; mp.set_start_method("fork"); from patator.patator import cli; raise SystemExit(cli())' ...
```

### WPScan sem WordPress

O Metasploitable 2 não possui WordPress; o módulo `wpscan` verifica o alvo e pula com aviso. Para exercitar, defina `WPSCAN_URL` apontando para uma instalação WordPress do laboratório.

### DVWA

Formulário validado em `http://192.168.56.3/dvwa/login.php` com `admin` / `password`.

### Rede host-only

O `vboxnet0` usa a subnet padrão `192.168.56.0/24` (host em `.1`). A tentativa de
mudar a subnet para `10.10.10.0/24` com `VBoxManage hostonlyif ipconfig` falhou
com `E_ACCESSDENIED` (a operação exige root no host), então o laboratório foi
mantido na subnet padrão. Os IPs `.3` (Meta) e `.4` (Kali) são estáticos e
sobrevivem a reboots; valide com `ifconfig eth0` após ligar as VMs.

### Backdoor vsftpd 2.3.4

O backdoor (porta 6200) só abre de forma confiável após reiniciar o serviço
`vsftpd`; o módulo `backdoor` do script faz esse restart via bindshell 1524
antes de disparar o exploit.
