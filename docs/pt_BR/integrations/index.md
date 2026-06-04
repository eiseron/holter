---
title: Integrações
description: Visão geral do módulo de integrações do Holter — conecte provedores externos e automatize ações durante incidentes.
---

# Módulo de Integrações

O módulo de integrações permite conectar serviços de terceiros ao seu workspace e automatizar ações quando incidentes de monitoramento ocorrem — por exemplo, pausar campanhas de anúncios quando um monitor cai e retomá-las automaticamente quando ele se recupera.

## Páginas

| Página | Descrição |
|--------|-----------|
| [Conectar um Provedor](connect-provider.md) | Navegue pelo catálogo de provedores e autorize o Holter a agir em seu nome |
| [Regras de Automação](rules.md) | Defina quais eventos disparam quais ações em quais alvos |
| [Log de Atividade](activity-log.md) | Histórico por integração de cada ação automática disparada |

## Como Funciona

1. Navegue pelo catálogo e conecte um provedor (autorização via OAuth).
2. Crie regras que mapeiam eventos de monitoramento para ações do provedor (ex.: `incident_opened` → pausar campanha).
3. Quando um incidente de monitor é aberto, o Holter dispara automaticamente as ações correspondentes.
4. Quando o incidente é resolvido, o Holter dispara as ações de recuperação correspondentes.
5. Cada disparo — bem-sucedido ou não — é registrado no log de atividade da integração.

## Provedores Suportados

| Provedor | Categoria | Ações |
|----------|-----------|-------|
| Google Ads | Anúncios | Pausar / retomar campanhas |
| Meta Ads | Anúncios | Pausar / retomar campanhas e conjuntos de anúncios |

## Relacionado

- [Módulo de Monitoramento](../monitoring/index.md) — incidentes que disparam integrações
- [Configurações — Tokens de API](../settings/api-tokens.md) — gerenciar tokens para a API de Integrações
