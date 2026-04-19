# Logs Técnicos

A página de Logs Técnicos lista cada verificação executada para um monitor, com opções de filtragem e ordenação.

## Acessando a Página

Na página de Configurações do Monitor, clique em **Logs Técnicos** ou navegue para `/monitoring/monitor/{monitor_id}/logs`.

## Gráfico de Dispersão

O gráfico no topo exibe os resultados das verificações ao longo do tempo. Cada ponto representa uma verificação; a posição no eixo Y corresponde à latência e a cor reflete o status. Isso oferece uma visão rápida de padrões de desempenho e janelas de indisponibilidade.

## Filtros

Use a barra de filtros para restringir os resultados:

| Filtro | Descrição |
|--------|-----------|
| Status | Filtre por resultado: Up, Down, Degraded, Compromised, Unknown |
| De | Exibe apenas verificações após esta data e hora |
| Até | Exibe apenas verificações antes desta data e hora |

Os filtros são aplicados imediatamente ao serem alterados.

## Tabela de Logs

Cada linha representa uma verificação:

| Coluna | Descrição |
|--------|-----------|
| Hora | Quando a verificação foi executada (fuso horário local) |
| Status | Status de saúde da verificação, exibido como uma pílula colorida. Inclui o código de resposta HTTP quando disponível (ex.: `UP 200`, `DOWN 503`). |
| Latência | Tempo de resposta em milissegundos |

Clique em **Ver Detalhes** em qualquer linha para abrir a página de [Detalhe do Log](log-detail.md) com as evidências completas.

## Ordenação

Clique em um cabeçalho de coluna para ordenar de forma crescente; clique novamente para decrescente.

## Paginação

A tabela exibe 50 entradas por página. Use os controles de paginação para navegar.

## Atualizações em Tempo Real

Novos resultados de verificação aparecem automaticamente no topo da lista sem recarregar a página.
