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

Um incidente é um problema aberto detectado pelo sistema. Há três tipos:

### Indisponibilidade (Downtime)

Aberto quando uma verificação HTTP falha. A saúde do monitor é definida como **DOWN** durante o período. O incidente fecha quando uma verificação bem-sucedida subsequente é registrada.

### Adulteração (Defacement)

Aberto quando o corpo da resposta contém uma palavra-chave negativa, sugerindo que o conteúdo da página foi manipulado. A saúde do monitor é definida como **COMPROMISED**.

### Expiração SSL (SSL Expiry)

Aberto quando uma verificação de certificado SSL detecta um problema:

| Causa Raiz | Saúde Resultante |
|------------|-----------------|
| Certificado expirado | COMPROMISED |
| Alerta crítico de expiração | COMPROMISED |
| Erro de conexão SSL | COMPROMISED |
| Outro (ex.: expiração iminente) | DEGRADED |

## Recálculo de Saúde

Após cada verificação, o Holter recalcula a saúde do monitor combinando dois sinais:

1. **Status do log mais recente** — o resultado da última verificação HTTP
2. **Incidentes abertos** — o status de maior severidade implicado por qualquer incidente aberto

O `health_status` final é o que tiver maior severidade entre esses dois sinais.

## Classificação no Dashboard

Os monitores são classificados no Dashboard para que os itens mais acionáveis apareçam primeiro:

1. Monitores ativos ordenados por severidade (DOWN → COMPROMISED → DEGRADED → UP → UNKNOWN)
2. Monitores pausados (sempre por último, independentemente do status de saúde)

Dentro do mesmo grupo de severidade, monitores criados mais recentemente aparecem acima dos mais antigos.
