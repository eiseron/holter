---
title: Novo Monitor
description: Crie um monitor e configure URL, método, palavras-chave, SSL e agendamento de verificações.
---

# Novo Monitor

O formulário Novo Monitor permite configurar uma URL para ser verificada em um intervalo recorrente.

## Acessando o Formulário

Clique em **Novo Monitor** na página de Monitores ou navegue diretamente para `/monitoring/workspaces/{workspace_slug}/monitor/new`.

Se o workspace estiver na cota máxima, o botão estará desabilitado. Exclua ou arquive um monitor existente antes de criar um novo.

## Configurações Técnicas

| Campo | Descrição |
|-------|-----------|
| URL | O endereço HTTP ou HTTPS completo a verificar. Deve começar com `http://` ou `https://`. |
| Método | Método HTTP: GET, POST, PUT, PATCH, DELETE, HEAD. |
| Timeout | Tempo máximo em segundos para aguardar resposta antes de marcar a verificação como falha. |
| Seguir Redirecionamentos | Quando habilitado, o verificador segue redirecionamentos HTTP. Desabilite para exigir um código de status exato na URL fornecida. |
| Máx. Redirecionamentos | Número máximo de redirecionamentos a seguir (visível apenas quando Seguir Redirecionamentos está ativo). |
| Corpo da Requisição | Payload enviado com a requisição (visível apenas para POST, PUT, PATCH). |
| Headers | Cabeçalhos HTTP personalizados como objeto JSON, ex.: `{"Authorization": "Bearer token"}`. |
| Palavras-chave Positivas | Palavras separadas por vírgula ou ponto-e-vírgula que devem aparecer no corpo da resposta. A ausência de uma delas marca a verificação como falha. |
| Palavras-chave Negativas | Palavras separadas por vírgula ou ponto-e-vírgula que **não** devem aparecer no corpo da resposta. A presença de uma delas marca a verificação como falha. |

## Configurações de Segurança

| Campo | Descrição |
|-------|-----------|
| Ignorar Erros SSL | Quando habilitado, problemas de certificado SSL (expirado, inválido, autoassinado) não causam falha nas verificações. Útil para serviços internos com certificados autoassinados. |

### Segurança de URLs

URLs de monitor que apontam para endereços privados ou internos são rejeitadas para prevenir SSRF: loopback, faixas RFC 1918, link-local, IPv6 ULA, IPv6 mapeado para IPv4, IPs codificados ou em forma curta (`0x7f000001`, `127.1`) e hosts de um único token sem ponto. Para permitir hosts internos específicos em uma implantação self-hosted, adicione-os à allowlist `:trusted_hosts` (veja [Canais de Notificação — Segurança da URL do webhook](../delivery/notification-channels.md#segurança-da-url-do-webhook) para o conjunto completo de regras e o snippet de configuração).

## Configurações de Intervalo

| Campo | Descrição |
|-------|-----------|
| Intervalo de Verificação | Com que frequência o monitor executa, em segundos. O intervalo mínimo permitido é definido pelo plano do workspace. |
| Estado | Estado inicial: **Ativo** (verificações iniciam imediatamente) ou **Pausado** (monitoramento suspenso). |

## Validação

O formulário valida em tempo real enquanto você digita. Erros aparecem inline abaixo de cada campo. O botão **Criar Monitor** fica desabilitado até que todos os campos obrigatórios sejam válidos.

## Após a Criação

Em caso de sucesso, você é redirecionado para a página de Configurações do Monitor recém-criado. O monitor começa a verificar no próximo ciclo de despacho (em até um minuto para monitores ativos).

Para vincular canais de notificação ao monitor, acesse **Canais** na barra lateral esquerda, abra um canal e selecione o monitor na lista de Monitores Vinculados. Veja [Canais de Notificação](../delivery/notification-channels.md).
