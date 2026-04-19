# Dashboard

O Dashboard é a tela principal do módulo de monitoramento. Ele exibe todos os monitores de um workspace em uma grade de cards, ordenados para que os problemas mais críticos apareçam primeiro.

## Acessando o Dashboard

Navegue para `/monitoring/workspaces/{workspace_slug}/dashboard`. O slug do workspace é único e aparece em todas as URLs do monitoramento.

## Cards de Monitor

Cada card exibe:

- **URL** — o endereço monitorado
- **Método e intervalo** — ex.: `GET • 300s`
- **Badge de saúde** — o status atual do monitor (veja [Status de Saúde](#status-de-saúde))
- **Sparkline** — um mini histórico dos últimos resultados de verificação
- **Link Detalhes** — navega para a página de Configurações do Monitor

## Status de Saúde

O badge em cada card reflete a saúde atual do monitor:

| Badge | Significado |
|-------|------------|
| UP | A última verificação teve sucesso e não há incidentes abertos |
| DEGRADED | O monitor está respondendo, mas com latência elevada ou falhas parciais |
| COMPROMISED | Há um incidente de SSL ou adulteração aberto |
| DOWN | A última verificação falhou ou há um incidente de indisponibilidade aberto |
| UNKNOWN | Nenhuma verificação foi executada ainda |
| PAUSED | O monitoramento está suspenso; o monitor não está sendo verificado |

## Ordem de Classificação

Os monitores são ordenados automaticamente para que os itens mais acionáveis apareçam primeiro:

1. Monitores ativos DOWN
2. Monitores ativos COMPROMISED
3. Monitores ativos DEGRADED
4. Monitores ativos UP
5. Monitores ativos UNKNOWN
6. Monitores pausados (qualquer status de saúde)

Dentro de cada grupo, os monitores criados mais recentemente aparecem antes dos mais antigos.

## Cota de Monitores

O cabeçalho exibe a cota do seu workspace, ex.: **3 / 10 monitores**. Quando a cota está cheia, o botão **Novo Monitor** é desabilitado e você precisa excluir ou arquivar um monitor existente antes de criar um novo.

## Criando um Novo Monitor

Clique em **Novo Monitor** no canto superior direito para abrir o formulário de criação. Veja [Novo Monitor](new-monitor.md) para mais detalhes.

## Estado Vazio

Se nenhum monitor foi criado ainda, o dashboard exibe um prompt para criar o primeiro.

## Atualizações em Tempo Real

O dashboard atualiza automaticamente via conexão ao vivo — não é necessário recarregar a página para ver mudanças de status.
