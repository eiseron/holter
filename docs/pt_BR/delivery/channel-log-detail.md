---
title: Detalhe do Log de Entrega
description: Detalhes completos de uma tentativa de envio de notificação — status, tipo de evento, mensagem de erro e links para o monitor e incidente relacionados.
---

# Detalhe do Log de Entrega

A página de Detalhe do Log de Entrega exibe os detalhes completos de uma tentativa de envio de notificação.

## Acessando a Página

Clique em **Ver Detalhes** em qualquer linha da lista de [Logs de Entrega](channel-logs.md), ou navegue para `/delivery/channel-logs/{log_id}`.

## Campos

| Campo | Descrição |
|-------|-----------|
| Status | Resultado do envio: `success` (sucesso) ou `failed` (falhou) |
| Tipo de Evento | Evento que disparou o envio: `down`, `up` ou `test` |
| Enviado em | Timestamp exato da tentativa de envio |
| Canal | O canal de notificação utilizado, com link para sua página de configurações |
| Monitor | Link para o monitor que disparou o alerta (quando aplicável) |
| Incidente | Link para o incidente que disparou o alerta (quando aplicável) |

## Mensagem de Erro

Se o envio falhou, a seção de mensagem de erro exibe o motivo. Para canais webhook, geralmente é um erro HTTP ou falha de conexão. Esta seção fica oculta quando o envio foi bem-sucedido.

## Relacionado

- [Logs de Entrega](channel-logs.md) — lista completa de tentativas de envio de um canal
- [Canais de Notificação](notification-channels.md) — configurações do canal
