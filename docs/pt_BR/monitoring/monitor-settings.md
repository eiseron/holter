# Configurações do Monitor

A página de Configurações do Monitor permite visualizar e editar a configuração de um monitor, disparar uma verificação manual e excluir o monitor.

## Acessando a Página

Clique em **Detalhes** em um card do Dashboard ou navegue para `/monitoring/monitor/{monitor_id}`.

## Cabeçalho

O cabeçalho da página exibe:

- **URL do Monitor** — o endereço monitorado
- **UUID** — o identificador único do monitor (útil para chamadas de API)
- **Badge de saúde** — saúde e estado lógico atuais (veja [Alertas & Incidentes](alert-incidents.md))
- **Métricas Diárias** — link para a página de histórico de uptime
- **Logs Técnicos** — link para a lista de logs de verificação
- **Botão Executar Agora** — dispara uma verificação imediata (veja abaixo)

## Gráfico de Visão Geral

Um gráfico abaixo do cabeçalho mostra o histórico dos resultados recentes de verificação. Cada ponto representa uma verificação, colorido por status.

## Formulário de Configuração

O formulário possui os mesmos campos do [Novo Monitor](new-monitor.md). As alterações são validadas ao vivo e salvas somente ao clicar em **Salvar Alterações**.

## Executar Agora

Clicar em **Executar Agora** enfileira uma verificação HTTP imediata fora do agendamento normal. Após disparar, o botão exibe uma contagem regressiva **Aguarde 60s** — verificações manuais são limitadas a uma por minuto por monitor.

A página atualiza automaticamente quando a verificação é concluída: o badge de saúde e o gráfico se atualizam sem recarregar a página.

## Pausar e Retomar

Para pausar o monitoramento, defina o campo **Estado** como **Pausado** e salve. O badge muda para o indicador PAUSED e o monitor para de ser verificado. Defina como **Ativo** para retomar.

## Excluindo um Monitor

Clique em **Excluir Monitor** na parte inferior do formulário. Um diálogo de confirmação aparecerá. Clique em **Sim, Excluir Completamente** para remover permanentemente o monitor e todos os logs, métricas e incidentes associados. Esta ação não pode ser desfeita.

## Atualizações em Tempo Real

A página assina eventos ao vivo. Quando uma verificação automática é concluída, o badge de saúde, o gráfico e o cabeçalho se atualizam automaticamente.
