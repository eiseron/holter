---
title: Log de Atividade
description: Como ler o log de atividade de integrações no Holter.
---

# Log de Atividade

O log de atividade registra cada ação que o Holter disparou através de uma integração — tanto envios para o provedor (saída) quanto eventos de webhook recebidos do provedor (entrada).

## Acessando o Log

Abra uma integração na lista de Integrações e clique na aba **Atividade**.

## Colunas do Log

| Coluna | Descrição |
|--------|-----------|
| Hora | Quando a ação ocorreu |
| Direção | `outbound` (Holter enviou ao provedor) ou `inbound` (provedor enviou ao Holter) |
| Ação | A ação disparada (ex.: `pause_campaign`) |
| Alvo | O ID e rótulo do alvo no provedor |
| Status | `success`, `failed` ou `retrying` |
| Duração | Tempo que a chamada à API do provedor levou |

## Status

- **success** — o provedor aceitou a requisição.
- **failed** — a requisição falhou e não será repetida (ex.: ID de alvo inválido, token revogado permanentemente).
- **retrying** — ocorreu um erro transitório; o Holter vai tentar novamente com backoff exponencial (5 min, 15 min, 60 min).

## Relacionado

- [Regras de Automação](rules.md) — regras que geram entradas no log de atividade
- [Conectar um Provedor](connect-provider.md) — status da integração que afeta os disparos
