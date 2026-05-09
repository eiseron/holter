---
title: Configurações do Workspace
description: Preferências do workspace inteiro. Apenas owner/admin.
---

# Configurações do Workspace

Abra as configurações do Workspace pela entrada **Configurações do workspace** na barra lateral (visível apenas para admins e owners) ou clicando no nome do workspace a partir das [Configurações de Usuário](user.md). A página fica em `/workspaces/{slug-do-workspace}`.

Apenas membros com papel `Owner` ou `Admin` podem editar esta página. A entrada na barra lateral fica oculta para membros comuns; abrir a URL diretamente os manda de volta ao dashboard.

## Idioma

O campo **Idioma** é o idioma padrão da UI do workspace. Aplica-se a:

1. **Membros sem preferência pessoal** — quando um membro visita uma página com escopo do workspace e ainda não definiu idioma nas suas próprias configurações de Usuário, o padrão do workspace é usado.
2. **Novos canais de notificação** — canais de e-mail e webhook criados sem idioma explícito herdam este padrão na hora do dispatch da notificação. Veja [Canais de Notificação](../delivery/notification-channels.md) para sobrescrever por canal.

Escolha **Português (Brasil)** ou **Inglês** e clique em **Salvar**. A mudança aplica na próxima renderização.
