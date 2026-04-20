---
title: Histórico de Incidentes
description: Navegue, filtre e pagine o histórico completo de incidentes de um monitor.
---

# Histórico de Incidentes

A página de Histórico de Incidentes lista todos os incidentes abertos para um monitor — abertos e resolvidos — com filtros, paginação e links para páginas de detalhe individuais.

## Acessando a Página

Em qualquer sub-página do monitor, clique em **Incidentes** na barra de navegação ou navegue para `/monitoring/monitor/{monitor_id}/incidents`.

## Filtros

Use a barra de filtros no topo para restringir os resultados:

| Filtro | Descrição |
|--------|-----------|
| Tipo | Filtre por tipo de incidente: Indisponibilidade, Adulteração, Expiração SSL |
| Estado | Filtre por estado: Aberto, Resolvido |
| De | Exibe apenas incidentes iniciados a partir desta data |
| Até | Exibe apenas incidentes iniciados até esta data |

Os filtros são aplicados imediatamente ao serem alterados.

## Tabela de Incidentes

Cada linha representa um incidente:

| Coluna | Descrição |
|--------|-----------|
| Desde | Data e hora em que o incidente foi aberto |
| Tipo | Categoria do problema (Indisponibilidade, Adulteração ou Expiração SSL) |
| Estado | **Aberto** (problema ativo) ou **Resolvido** (problema encerrado) |
| Duração | Quanto tempo o incidente durou, em minutos. Exibe um traço (—) para incidentes ainda abertos |
| Causa Raiz | Descrição curta do motivo pelo qual o incidente foi aberto, truncada para caber na linha |

Clique em **Detalhes** em qualquer linha para abrir a página de [Detalhe do Incidente](incident-detail.md) com a causa raiz completa e o snapshot do monitor capturado na ocasião.

## Paginação

A tabela exibe 25 incidentes por página por padrão. Use os controles de paginação para navegar entre as páginas.

## Atualizações em Tempo Real

Novos incidentes aparecem automaticamente quando são abertos. As linhas existentes se atualizam quando um incidente é resolvido, sem recarregar a página.
