# Documentação — Laboratório de Brute Force (DIO/Santander)

Desafio: criar ataques de força bruta de senhas com Medusa e Kali Linux contra o
Metasploitable 2, em ambiente controlado, e publicar o resultado em um repositório.

| Documento | Conteúdo |
|---|---|
| [planejamento.md](planejamento.md) | Objetivo, escopo, fases, critérios de aceite, riscos e próximos passos |
| [ambiente.md](ambiente.md) | Host, VMs, rede host-only, acesso (túnel/RDP/SSH) e troubleshooting |
| [ataques.md](ataques.md) | Script `lab-attacks.sh`, mapa do menu do curso, comandos e resultados |
| [resultados.md](resultados.md) | Resumo dos achados, destaques e mitigações |

## Status

- Infraestrutura do laboratório: concluída
- Acesso remoto (RDP via túnel SSH): concluído
- Validação dos ataques (smoke test): concluída
- Execução final (`all`) e coleta de evidências: concluída
- Ataques extras (VNC, bancos, Tomcat, bindshell e vsftpd backdoor): validados
- Publicação do repositório: concluída

## Entregáveis

- `lab-attacks.sh` — orquestrador dos ataques (executado dentro do Kali)
- `scripts/vsftpd_backdoor.py` — exploit do backdoor vsftpd 2.3.4
- `wordlists/` — listas de usuários, senhas e credential stuffing
- `configs/` — configuração de rede das VMs
- `evidence/20261107-093736/` — logs da execução final
- `images/` — capturas de tela do nmap, do resumo dos ataques e do IP do Meta
- `docs/` — este conjunto de documentos
