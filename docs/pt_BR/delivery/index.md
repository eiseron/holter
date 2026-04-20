---
title: Entrega
description: Visão geral do módulo de entrega do Holter — canais de notificação e envio de alertas.
---

# Módulo de Entrega

O módulo de entrega permite que você receba alertas quando monitores caem ou se recuperam. Você define canais de notificação uma vez e os vincula a quantos monitores quiser.

## Páginas

| Página | Descrição |
|--------|-----------|
| [Canais de Notificação](notification-channels.md) | Crie, edite, teste e exclua canais de notificação para seu workspace |

## Como Funciona

1. Crie um canal de notificação (webhook, e-mail, Slack ou Discord).
2. Vincule o canal a um ou mais monitores pela página de configurações do canal (seção Monitores Vinculados).
3. Quando um monitor detecta uma falha, o Holter enfileira um job de notificação e entrega o alerta.
4. Quando o monitor se recupera, o Holter envia automaticamente um alerta de recuperação.

## Tipos de Canal

| Tipo | Método de entrega |
|------|------------------|
| Webhook | HTTP POST com payload JSON para qualquer URL |
| E-mail | E-mail enviado via provedor de e-mail configurado |
| Slack | Payload JSON formatado como mensagem Slack |
| Discord | Payload JSON formatado como embed Discord |

## Relacionado

- [Módulo de Monitoramento](../monitoring/index.md) — incidentes que disparam a entrega
