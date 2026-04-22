---
title: Logs de Entrega
description: Histórico de cada tentativa de envio de notificação por canal, com filtros por status e intervalo de datas.
---

# Logs de Entrega

A página de Logs de Entrega lista todas as tentativas de envio de notificação de um canal, com opções de filtro e ordenação.

## Acessando a Página

Na página de configurações do canal, clique em **Ver Logs**, ou navegue para `/delivery/notification-channels/{id}/logs`.

## Filtros

Use a barra de filtros para refinar os resultados:

| Filtro | Descrição |
|--------|-----------|
| Resultados | Número de entradas por página: 25, 50 ou 100 |
| Status | Filtre pelo resultado: Sucesso ou Falhou |
| De | Exibe apenas envios nesta data ou após |
| Até | Exibe apenas envios nesta data ou antes |

Os filtros são aplicados imediatamente ao serem alterados.

## Tabela de Logs

Cada linha representa uma tentativa de envio:

| Coluna | Descrição |
|--------|-----------|
| Horário | Quando o envio foi tentado (seu fuso horário local) |
| Status | Resultado do envio: `success` (sucesso) ou `failed` (falhou) |
| Evento | Tipo de evento que disparou o envio: `down`, `up` ou `test` |

## Ordenação

Clique no cabeçalho da coluna **Horário** ou **Status** para ordenar. Clique novamente para inverter a direção.

## Paginação

Use os controles de paginação abaixo da tabela para navegar entre as páginas.

## Retenção de Logs

Os logs de entrega são mantidos por 90 dias. Após esse período, são removidos automaticamente e não podem ser recuperados.
