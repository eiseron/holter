---
title: Regras de Automação
description: Como criar e gerenciar regras de automação nas integrações do Holter.
---

# Regras de Automação

Uma regra vincula um evento de monitoramento a uma ação do provedor em um alvo específico. Quando o evento ocorre, o Holter dispara a ação automaticamente.

## Criando uma Regra

1. Abra uma integração ativa na lista de Integrações.
2. Clique em **Adicionar Regra**.
3. Selecione o **Monitor** ao qual a regra se aplica.
4. Selecione o **Evento** que dispara a regra:
   - `incident_opened` — um monitor entra em falha
   - `incident_resolved` — um monitor se recupera
   - `monitor_paused` — um monitor é pausado manualmente
   - `monitor_resumed` — um monitor é retomado manualmente
5. Selecione a **Ação** a ser disparada:
   - `pause_campaign` / `resume_campaign` — campanhas do Google Ads ou Meta Ads
   - `pause_ad_set` / `resume_ad_set` — conjuntos de anúncios do Meta Ads
6. Informe o **ID do Alvo** — o identificador do provedor para a campanha ou conjunto de anúncios.
7. Opcionalmente, informe um **Rótulo do Alvo** para facilitar a identificação no log de atividade.
8. Clique em **Salvar**.

## Retomada Segura

Quando um evento `incident_resolved` dispara uma ação `resume_campaign`, o Holter retoma apenas campanhas que ele mesmo pausou — não retomará uma campanha que já estava pausada antes do incidente. Isso evita que o Holter ative inadvertidamente campanhas que você havia interrompido por outros motivos.

## Excluindo uma Regra

Abra a regra na página da integração e clique em **Excluir**. Os registros existentes no log de atividade não são afetados.

## Relacionado

- [Log de Atividade](activity-log.md) — veja quais regras foram disparadas e seus resultados
- [Conectar um Provedor](connect-provider.md) — uma regra requer uma integração ativa
