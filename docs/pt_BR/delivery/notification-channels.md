---
title: Canais de Notificação
description: Crie e gerencie canais de notificação para receber alertas quando monitores mudam de estado.
---

# Canais de Notificação

Um canal de notificação é um destino para onde o Holter envia alertas. Cada canal pertence a um workspace e pode ser vinculado a vários monitores.

## Criando um Canal

1. Clique em **Canais** na barra lateral esquerda.
2. Clique em **Novo Canal**.
3. Preencha os campos abaixo e clique em **Criar Canal**.

## Campos

| Campo | Obrigatório | Descrição |
|-------|-------------|-----------|
| Nome | Sim | Rótulo legível para o canal (ex: "Slack da Equipe de Ops"). |
| Tipo | Sim | Um de: `webhook`, `email`, `slack`, `discord`. |
| Destino | Sim | O endereço de entrega. Veja o formato esperado por tipo abaixo. |

### Formato do destino por tipo

| Tipo | Formato esperado |
|------|-----------------|
| `webhook` | URL válida `http://` ou `https://`. |
| `slack` | URL de webhook incoming do Slack (`https://hooks.slack.com/…`). |
| `discord` | URL de webhook do Discord (`https://discord.com/api/webhooks/…`). |
| `email` | Endereço de e-mail válido (ex: `ops@exemplo.com`). |

## Editando um Canal

Clique no nome do canal na lista de Canais (`/workspaces/{workspace_slug}/channels`) para abrir sua página de configurações em `/delivery/notification-channels/{id}`. Você pode atualizar o nome e o destino. O tipo do canal não pode ser alterado após a criação.

## Enviando uma Notificação de Teste

Na página de configurações do canal, clique em **Enviar Teste** para enfileirar uma notificação de teste. O payload de teste inclui o nome do canal e um timestamp. Isso é útil para verificar se o destino está acessível antes de vincular o canal a um monitor.

## Excluindo um Canal

Na página de lista de canais, clique em **Excluir** ao lado do canal. Isso remove o canal e todos os vínculos com monitores. Monitores vinculados a um canal excluído não receberão mais notificações por aquele canal.

## Vinculando Canais a Monitores

Os canais gerenciam o vínculo com os monitores. Para conectar um canal a um ou mais monitores:

1. Abra a página de configurações do canal.
2. Na seção **Monitores Vinculados**, marque cada monitor que deve disparar notificações por este canal.
3. Clique em **Salvar Alterações**.

Desmarcar um monitor e salvar interrompe imediatamente as notificações futuras daquele monitor por este canal.

Você também pode gerenciar os vínculos via API — inclua um array `notification_channel_ids` no corpo da requisição de criação ou atualização do monitor.

## Formato do Payload

Quando um monitor cai ou se recupera, o Holter envia o seguinte payload JSON para canais webhook, Slack e Discord:

```json
{
  "version": "1",
  "event": "monitor_down",
  "timestamp": "2026-04-20T10:00:00Z",
  "monitor": {
    "id": "...",
    "url": "https://exemplo.com",
    "method": "get"
  },
  "incident": {
    "id": "...",
    "type": "downtime",
    "started_at": "2026-04-20T10:00:00Z",
    "resolved_at": null
  }
}
```

Eventos: `monitor_down`, `monitor_up`. Para incidentes de expiração de SSL, o evento é `ssl_expiry_down` / `ssl_expiry_up`.

## Relacionado

- [Módulo de Monitoramento](../monitoring/index.md) — incidentes que disparam a entrega
- [Referência da API](../../api/openapi.yml) — endpoints REST para canais de notificação
