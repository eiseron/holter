---
title: Detalhe do Incidente
description: Evidências completas de um único incidente, incluindo causa raiz e o snapshot do monitor na ocasião.
---

# Detalhe do Incidente

A página de Detalhe do Incidente exibe tudo que foi registrado quando um incidente foi aberto: o tipo, a linha do tempo, a causa raiz e a configuração exata do monitor que estava ativa no momento.

## Acessando a Página

Clique em **Detalhes** em qualquer linha na página de [Histórico de Incidentes](incidents.md) ou navegue para `/monitoring/incidents/{incident_id}`.

## Visão Geral do Incidente

A seção superior exibe:

| Campo | Descrição |
|-------|-----------|
| Tipo | Categoria: Indisponibilidade, Adulteração ou Expiração SSL |
| Estado | **Aberto** ou **Resolvido** |
| Iniciado em | Data e hora em que o incidente foi aberto |
| Resolvido em | Data e hora em que o incidente foi encerrado (ausente se ainda aberto) |
| Duração | Tempo entre a abertura e a resolução (ausente se ainda aberto) |

## Causa Raiz

O campo de causa raiz contém a mensagem gerada pela verificação que disparou o incidente. Exemplos:

- `HTTP Error: 503` — o servidor retornou uma resposta fora do intervalo 2xx
- `Missing required keywords: "checkout", "login"` — palavras-chave obrigatórias não foram encontradas
- `Found forbidden keywords: "hacked"` — uma palavra-chave proibida correspondeu
- `Certificate expires in 6 days (Critical)` — certificado SSL próximo do vencimento
- `SSL Error: :connection_refused` — o handshake SSL falhou

## Snapshot do Monitor

O snapshot do monitor registra os valores de configuração que estavam ativos quando o incidente foi aberto: URL, método, palavras-chave, intervalo e outras configurações. Isso permite auditar quais regras estavam em vigor mesmo que o monitor tenha sido atualizado desde então.

## Navegação

Use a barra de sub-navegação para mover-se entre as páginas de Detalhes, Métricas Diárias, Logs Técnicos e Incidentes do monitor.
