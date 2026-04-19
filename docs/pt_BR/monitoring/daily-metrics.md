# Métricas Diárias

A página de Métricas Diárias exibe um resumo agregado de uptime para um monitor, dividido por dia.

## Acessando a Página

Na página de Configurações do Monitor, clique em **Métricas Diárias** ou navegue para `/monitoring/monitor/{monitor_id}/daily_metrics`.

## Gráfico

Um gráfico no topo visualiza o percentual de uptime diário ao longo do tempo, oferecendo uma indicação visual rápida de períodos com confiabilidade reduzida.

## Tabela de Métricas

Cada linha representa um dia do calendário:

| Coluna | Descrição |
|--------|-----------|
| Data | O dia do calendário (UTC) |
| Uptime % | Percentual de verificações que retornaram status de sucesso naquele dia. Exibido em verde quando alto, vermelho quando baixo. |
| Latência Média | Tempo médio de resposta em milissegundos em todas as verificações do dia |
| Tempo de Inatividade | Total de minutos de indisponibilidade confirmada naquele dia |

## Ordenação

Clique em qualquer cabeçalho de coluna para ordenar por aquela coluna. Clique novamente para inverter a ordem.

## Paginação

A tabela exibe 30 dias por página. Use os controles de paginação na parte inferior para navegar a períodos anteriores.

## Estado Vazio

Se nenhuma verificação foi executada ainda, a tabela estará vazia e uma mensagem indicará que as métricas aparecerão após o primeiro ciclo de verificação.

## Atualizações em Tempo Real

A página atualiza automaticamente quando novas métricas diárias são agregadas (uma vez por dia por padrão).
