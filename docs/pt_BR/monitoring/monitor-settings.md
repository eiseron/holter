---
title: Configurações do Monitor
description: Edite um monitor, execute uma verificação manual, visualize o histórico de saúde e exclua o monitor.
---

# Configurações do Monitor

A página de Configurações do Monitor permite visualizar e editar a configuração de um monitor, disparar uma verificação manual e excluir o monitor.

## Acessando a Página

Clique em **Detalhes** em um card do Dashboard ou navegue para `/monitoring/monitor/{monitor_id}`.

## Barra de Navegação

Uma barra de sub-navegação abaixo do cabeçalho vincula a todas as páginas relacionadas ao monitor. A página atual é omitida da barra:

- **Detalhes do Monitor** — esta página
- **Métricas Diárias** — histórico de uptime
- **Logs Técnicos** — lista de logs de verificação
- **Incidentes** — histórico de incidentes

## Cabeçalho

O cabeçalho da página exibe:

- **URL do Monitor** — o endereço monitorado
- **UUID** — o identificador único do monitor (útil para chamadas de API)
- **Badge de saúde** — saúde e estado lógico atuais (veja [Alertas & Incidentes](alert-incidents.md))
- **Botão Executar Agora** — dispara uma verificação imediata (veja abaixo)

## Painel de Incidentes Ativos

Se o monitor tiver incidentes abertos, um painel é exibido abaixo da barra de navegação listando cada um com seu tipo, quando foi aberto e uma causa raiz resumida. Clique na linha do incidente para abrir a página de [Detalhe do Incidente](incident-detail.md).

O painel desaparece automaticamente quando todos os incidentes são resolvidos.

## Gráfico de Visão Geral

Um gráfico abaixo do cabeçalho mostra o histórico dos resultados recentes de verificação. Cada ponto representa uma verificação, colorido por status.

## Formulário de Configuração

O formulário possui os mesmos campos do [Novo Monitor](new-monitor.md). As alterações são validadas ao vivo e salvas somente ao clicar em **Salvar Alterações**.

## Executar Agora

Clicar em **Executar Agora** enfileira uma verificação HTTP imediata fora do agendamento normal. Após disparar, o botão exibe uma contagem regressiva **Aguarde 60s** — verificações manuais são limitadas a uma por minuto por monitor.

A página atualiza automaticamente quando a verificação é concluída: o badge de saúde e o gráfico se atualizam sem recarregar a página.

## Ignorar SSL

O campo **Ignorar Erros de SSL** no formulário instrui o Holter a pular as verificações de certificado SSL para este monitor. Quando habilitado:

- Nenhum incidente de expiração SSL é aberto.
- Qualquer incidente de expiração SSL aberto é resolvido na próxima vez que **Executar Agora** for clicado ou uma verificação agendada for executada.
- As verificações HTTP continuam sendo executadas normalmente.

Útil para monitores de serviços internos que intencionalmente usam certificados autoassinados.

## Pular Verificações de Expiração de Domínio

O campo **Pular Verificações de Expiração de Domínio** desabilita consultas WHOIS/RDAP no domínio do monitor. Quando habilitado:

- Nenhum incidente de expiração de domínio é aberto.
- Qualquer incidente de expiração de domínio aberto é resolvido na próxima verificação agendada.
- As verificações de SSL e HTTP continuam normalmente.

As verificações de domínio executam no máximo uma vez a cada 24 horas por monitor e são puladas silenciosamente quando a URL aponta para um IP literal ou para um host interno. Habilite este campo em monitores cujo domínio não é relevante (por exemplo, endpoints internos de staging).

## Pausar e Retomar

Para pausar o monitoramento, defina o campo **Estado** como **Pausado** e salve. O badge muda para o indicador PAUSED e o monitor para de ser verificado. Defina como **Ativo** para retomar.

## Excluindo um Monitor

Clique em **Excluir Monitor** na parte inferior do formulário. Um diálogo de confirmação aparecerá. Clique em **Sim, Excluir Completamente** para remover permanentemente o monitor e todos os logs, métricas e incidentes associados. Esta ação não pode ser desfeita.

## Atualizações em Tempo Real

A página assina eventos ao vivo. Quando uma verificação automática é concluída, o badge de saúde, o gráfico e o cabeçalho se atualizam automaticamente.
