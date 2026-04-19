# Primeiros Passos com o Holter

O Holter monitora suas URLs em um intervalo recorrente, rastreia o histórico de uptime e abre incidentes quando problemas são detectados. Este guia apresenta os conceitos fundamentais e o caminho para criar seu primeiro monitor.

## Conceitos Fundamentais

### Workspace

Um workspace é um ambiente isolado que agrupa monitores. Cada workspace tem uma cota de monitores — o número máximo permitido pelo seu plano. O slug do workspace aparece nas URLs do dashboard e do formulário de novo monitor (ex.: `/monitoring/workspaces/minha-empresa/dashboard`). As páginas de monitor individual, logs e métricas utilizam o ID do monitor ou do log.

### Monitor

Um monitor é uma verificação configurada contra uma única URL. Ele é executado em um intervalo fixo (ex.: a cada 5 minutos) e registra o resultado de cada verificação como uma entrada de log. Um monitor tem dois estados independentes:

- **Status de saúde** — o que a última verificação encontrou: `up`, `degraded`, `compromised`, `down` ou `unknown`
- **Estado lógico** — se a verificação está ativa: `active`, `paused` ou `archived`

### Verificação (Check)

Cada vez que um monitor é executado, ele faz uma requisição HTTP para a URL configurada e avalia a resposta de acordo com suas regras (código de status, palavras-chave, validade SSL). O resultado é armazenado como uma entrada de log e usado para atualizar o status de saúde do monitor.

### Incidente

Um incidente é um problema em aberto que persiste até ser resolvido. O Holter abre incidentes automaticamente para indisponibilidade, problemas de SSL e adulteração (correspondência de palavras-chave negativas). O status de saúde do monitor reflete o incidente aberto de maior severidade.

## Configurando Seu Primeiro Monitor

1. Abra o [Dashboard](monitoring/dashboard.md) do seu workspace.
2. Clique em **Novo Monitor**.
3. Informe a URL que deseja monitorar (ex.: `https://exemplo.com.br`).
4. Escolha um **Método** HTTP (GET é o padrão para a maioria dos sites).
5. Defina um **Intervalo de Verificação** — 300 segundos (5 minutos) é um bom ponto de partida.
6. Opcionalmente, adicione **Palavras-chave Positivas** — palavras que devem aparecer no corpo da resposta, como `login` ou `início`.
7. Clique em **Criar Monitor**.

O monitor aparece no dashboard e começa a verificar dentro do próximo minuto.

## Lendo o Dashboard

Os monitores são ordenados por urgência: monitores DOWN aparecem primeiro, seguidos de COMPROMISED, DEGRADED, UP e por último PAUSED. O badge de saúde em cada card é atualizado em tempo real — sem necessidade de recarregar a página.

Veja [Dashboard](monitoring/dashboard.md) para uma explicação completa do layout dos cards e do indicador de cota.

## Investigando um Problema

Quando um monitor fica DOWN ou DEGRADED:

1. Clique em **Detalhes** no card do monitor.
2. Revise o **Gráfico de Visão Geral** para identificar o padrão (súbito ou gradual).
3. Clique em **Logs Técnicos** para ver os resultados individuais de cada verificação.
4. Clique em **Ver Detalhes** em um log de falha para acessar as evidências HTTP completas: código de status, cadeia de redirecionamentos, headers e conteúdo do corpo.

Veja [Detalhe do Log](monitoring/log-detail.md) para uma explicação completa da página de evidências.

## Pausar e Retomar

Se precisar colocar um serviço offline para manutenção, defina o **Estado** do monitor como **Pausado** na página de Configurações do Monitor. Monitores pausados são movidos para o final do dashboard e ficam excluídos da detecção de incidentes até serem retomados.

## Próximos Passos

- [Visão Geral do Módulo de Monitoramento](monitoring/index.md)
- [Referência de Alertas & Incidentes](monitoring/alert-incidents.md)
