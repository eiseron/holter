---
title: Lançamentos
description: Histórico de mudanças visíveis ao usuário em cada versão do Holter.
---

# Lançamentos

Esta página lista as mudanças visíveis ao usuário em cada versão do Holter, da mais recente para a mais antiga. O seletor de versão no topo permite navegar entre snapshots congelados de versões anteriores.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/). O Holter usa [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## v0.1.0 — Versão inicial

_A data será preenchida quando a v0.1.0 for publicada._

### Adicionado

#### Identidade

- **Cadastro e login** — crie uma conta com e-mail e senha e acesse o painel do workspace. Veja [Cadastro](identity/sign-up.md) e [Login](identity/sign-in.md).
- **Verificação de e-mail** — link de ativação de uso único e curta duração enviado no cadastro. Veja [Verificação de E-mail](identity/email-verification.md).
- **Esqueci minha senha** — recuperação de acesso por link enviado por e-mail, com validade de 15 minutos e revogação das sessões existentes. Veja [Esqueci minha senha](identity/forgot-password.md).
- **Workspace padrão no cadastro** — toda conta nova recebe um workspace e é vinculada como `owner`. Veja a [visão geral de Identidade](identity/index.md).

#### Monitoramento

- **Monitores** — verificações HTTP recorrentes contra uma única URL, com método, intervalo, palavras-chave positivas e negativas e validação de SSL configuráveis. Veja [Monitores](monitoring/dashboard.md) e [Novo Monitor](monitoring/new-monitor.md).
- **Status de saúde** — cada monitor reporta `up`, `degraded`, `compromised`, `down` ou `unknown`, derivado da última verificação e de incidentes em aberto. Veja [Alertas & Incidentes](monitoring/alert-incidents.md).
- **Estado lógico** — monitores podem estar `active`, `paused` ou `archived` independentemente do status de saúde. Veja [Configurações do Monitor](monitoring/monitor-settings.md).
- **Métricas diárias** — percentual de uptime, latência média e minutos de indisponibilidade por dia para cada monitor. Veja [Métricas Diárias](monitoring/daily-metrics.md).
- **Logs técnicos** — registro completo de cada verificação executada, filtrável por status e intervalo de datas, com evidências HTTP (código de status, cadeia de redirecionamentos, headers, corpo) por entrada. Veja [Logs Técnicos](monitoring/logs.md) e [Detalhe do Log](monitoring/log-detail.md).
- **Histórico de incidentes** — incidentes de indisponibilidade, SSL e adulteração abertos automaticamente quando as verificações falham, com snapshot de causa raiz por incidente. Veja [Histórico de Incidentes](monitoring/incidents.md) e [Detalhe do Incidente](monitoring/incident-detail.md).

#### Entrega

- **Canais de notificação** — canais no nível do workspace que recebem alertas quando monitores falham ou se recuperam. Canais podem ser vinculados a múltiplos monitores. Veja [Canais de Notificação](delivery/notification-channels.md).
- **Canal webhook** — HTTP POST com payload JSON para qualquer URL.
- **Canal de e-mail** — alertas entregues através do provedor de e-mail configurado.
- **Logs de entrega** — histórico, por canal, de cada tentativa de envio de notificação. Veja [Logs de Entrega](delivery/channel-logs.md).

#### Configurações

- **Configurações do usuário** — página por conta, listando os workspaces aos quais você pertence. Veja [Usuário](settings/user.md).
- **Configurações do workspace** — configuração do workspace, editável por membros com papel `Owner` ou `Admin`. Veja [Workspace](settings/workspace.md).
- **Tokens da API** — tokens do workspace para a API pública, gerenciados pelo `Owner`. Veja [Tokens da API](settings/api-tokens.md).
