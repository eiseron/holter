---
title: Alertas & Incidentes
description: Como o status de saúde é calculado, tipos de incidentes, estado lógico e lógica de classificação do dashboard.
---

# Alertas & Incidentes

Este documento explica como o Holter determina a saúde de um monitor, o que são incidentes e como os dois interagem.

## Status de Saúde

Cada monitor tem um campo `health_status` que resume sua condição atual:

| Status | Severidade | Significado |
|--------|-----------|------------|
| DOWN | 4 (maior) | A última verificação falhou ou há um incidente de indisponibilidade aberto |
| COMPROMISED | 3 | Um erro de SSL ou incidente de adulteração está aberto |
| DEGRADED | 2 | O monitor está acessível, mas com desempenho abaixo do esperado |
| UP | 1 | Todas as verificações passam e não há incidentes abertos |
| UNKNOWN | 0 | Nenhuma verificação foi executada ainda |

Quando múltiplos sinais divergem, o de maior severidade prevalece.

## Estado Lógico

O `logical_state` é separado da saúde e controla se o monitor está executando ativamente:

| Estado | Significado |
|--------|------------|
| active | As verificações são executadas conforme o agendamento |
| paused | As verificações estão suspensas; o monitor não é avaliado |
| archived | O monitor está desabilitado e excluído das contagens de cota |

Um monitor pausado mantém seu último status de saúde conhecido, mas não é reavaliado até ser retomado.

## Incidentes

Um incidente é um problema aberto detectado pelo sistema. Há quatro tipos:

### Indisponibilidade (Downtime)

Aberto quando uma verificação HTTP falha. A saúde do monitor é definida como **DOWN** durante o período. O incidente fecha quando uma verificação bem-sucedida subsequente é registrada.

### Adulteração (Defacement)

Aberto quando o corpo da resposta contém uma palavra-chave negativa, sugerindo que o conteúdo da página foi manipulado. A saúde do monitor é definida como **COMPROMISED**.

### Expiração SSL (SSL Expiry)

Aberto quando uma verificação de certificado SSL detecta um problema:

| Causa Raiz | Saúde Resultante |
|------------|-----------------|
| Certificado expirado | COMPROMISED |
| Vencimento em até 7 dias (Crítico) | COMPROMISED |
| Erro de conexão SSL | COMPROMISED |
| Vencimento em até 15 dias (Aviso) | DEGRADED |

Incidentes de expiração SSL são suprimidos quando o campo **Ignorar Erros de SSL** está habilitado no monitor. Qualquer incidente de expiração SSL aberto é resolvido na próxima verificação após salvar a configuração. Veja [Configurações do Monitor](monitor-settings.md#ssl-ignore).

### Expiração de Domínio (Domain Expiry)

Aberto quando uma verificação de registro de domínio (WHOIS/RDAP) detecta uma expiração próxima ou já ocorrida:

| Causa Raiz | Saúde Resultante |
|------------|-----------------|
| Domínio expirado | COMPROMISED |
| Vencimento em até 7 dias (Crítico) | COMPROMISED |
| Vencimento em até 30 dias (Aviso) | DEGRADED |

Os dados de expiração de domínio são consultados no máximo uma vez a cada 24 horas por monitor, via endpoint RDAP do registrador. As consultas são puladas quando a URL aponta para um IP literal ou um host interno. Erros transitórios de RDAP (limites de taxa, indisponibilidade do registrador) são apenas registrados em log e **não** abrem incidentes — apenas estados confirmados de expiração ou pré-expiração abrem.

Incidentes de expiração de domínio são suprimidos quando o campo **Pular Verificações de Expiração de Domínio** está habilitado no monitor. Qualquer incidente de expiração de domínio aberto é resolvido na próxima verificação após salvar a configuração.

## Recálculo de Saúde

Após cada verificação, o Holter recalcula a saúde do monitor combinando dois sinais:

1. **Status do log mais recente** — o resultado da última verificação HTTP
2. **Incidentes abertos** — o status de maior severidade implicado por qualquer incidente aberto

O `health_status` final é o que tiver maior severidade entre esses dois sinais.

## Classificação no Dashboard

Os monitores são classificados no Dashboard para que os itens mais acionáveis apareçam primeiro:

1. Monitores ativos ordenados por severidade (DOWN → COMPROMISED → DEGRADED → UP → UNKNOWN)
2. Dentro do mesmo grupo de severidade, monitores com mais incidentes abertos aparecem primeiro
3. Monitores pausados (sempre por último, independentemente do status de saúde)

## Histórico de Incidentes

Todos os incidentes são registrados permanentemente e acessíveis na página de [Histórico de Incidentes](incidents.md). O histórico pode ser filtrado por tipo, estado (aberto ou resolvido) e período. Cada entrada vincula a uma página de [Detalhe do Incidente](incident-detail.md) que exibe a causa raiz completa e o snapshot do monitor capturado quando o incidente foi aberto.
