---
title: Tokens da API
description: Crie, escope e revogue tokens de acesso programático para um workspace pelo dashboard.
---

# Tokens da API

A página **Tokens da API** permite criar tokens escopados ao workspace para que um script externo, job de CI ou serviço de terceiros possa atuar no seu workspace sem precisar fazer login com sua conta.

Acesse pelo sidebar do workspace (**Tokens da API**, abaixo de **Configurações**) ou diretamente em `/identity/workspaces/{slug-do-workspace}/api-tokens`.

## Quem vê esta página

| Papel | Pode abrir | Pode criar | Pode revogar |
|-------|------------|------------|--------------|
| Proprietário | Sim | Sim | Sim |
| Admin | Sim — só listagem | Não | Não |
| Membro | Não (a URL devolve pro dashboard) | — | — |

Se você não vê o item no sidebar, peça a um proprietário do workspace pra te promover.

## Criando um token

1. Dê um **nome** que você-no-futuro vai reconhecer — por exemplo `CI / dashboard só leitura` ou `release-bot`. O nome aparece junto do token na lista de ativos, então um rótulo claro facilita revogar depois.
2. Marque as **permissões** que o token deve conceder. Cada caixa mostra um rótulo em linguagem natural, o identificador técnico do escopo (caso a integração que você está configurando peça por ele) e uma descrição de uma linha do que ativá-lo significa. Marque só o que a integração realmente precisa — um token sem permissões de escrita não consegue apagar um monitor por engano.
3. Clique em **Gerar token**.

O token é **exibido uma única vez** em um painel no topo da página. Copie-o pro seu gerenciador de segredos (1Password, Vault, GitHub Actions secrets etc.) na hora — depois que você dispensa o painel, o Holter não tem como te mostrar de novo. Se você perder, o único caminho é revogar e criar um novo.

Após dispensar, o formulário é limpo automaticamente, então você pode seguir criando outro token com permissões diferentes se precisar.

## Permissões, em linguagem natural

Ao criar um token, cada permissão tem um rótulo e uma descrição curta. A UI é a fonte da verdade — os rótulos abaixo são exatamente os que aparecem na tela:

* **Ver workspace** — ler o nome e metadados básicos do workspace
* **Ver monitores** / **Gerenciar monitores** — listar e acompanhar saúde dos monitores, ou criar/editar/excluir monitores
* **Ver logs** / **Ver métricas** / **Ver incidentes** — ler verificações brutas, números diários de uptime e linha do tempo de incidentes
* **Ver canais de notificação** / **Gerenciar canais de notificação** — listar canais webhook e e-mail, ou criar/editar/excluir (e rotacionar segredos de assinatura)
* **Enviar pings de teste** — disparar uma entrega de teste por um canal
* **Ver histórico de entregas** — ler o histórico de entregas de notificações passadas

Escolha o menor conjunto que permite a integração fazer o trabalho dela. Se descobrir depois que precisa de mais, crie um token novo com escopo mais amplo e revogue o estreito.

## A lista de tokens ativos

Todo token criado neste workspace aparece na tabela **Tokens ativos**:

* **Nome** — como você chamou
* **Permissões** — os rótulos marcados na criação
* **Último uso** — o momento em que o Holter viu o token em uma requisição pela última vez, ou **Nunca** se não foi usado ainda
* **Status** — **Ativo** ou **Revogado**
* **Revogar** — botão de ação para aposentar o token

A lista é por workspace: tokens criados em outro workspace não aparecem aqui.

## Revogando um token

Clique em **Revogar** na linha, confirme no prompt, e o token deixa de funcionar a partir da próxima requisição. A linha permanece na lista com status **Revogado** pra deixar registro. A revogação não pode ser desfeita — se quiser o token de volta, crie um novo.

Você deve revogar um token quando:

* O script ou job de CI que usava foi descontinuado
* Você suspeita que o token vazou (commitado no git por acidente, postado em chat etc.)
* A integração está sendo rotacionada pra um conjunto de permissões diferente
* A pessoa que criou o token não precisa mais criar tokens

## O que acontece quando muda a participação

Se um proprietário do workspace te remover do workspace, todos os tokens que você criou contra esse workspace são **revogados automaticamente** no mesmo instante. Você não precisa revogar manualmente antes de sair — o Holter cuida disso. O contrário também vale: você não consegue manter um token vivo depois de perder acesso.

## Boas práticas

* **Dê nomes pelo consumidor**, não pela data. `release-bot` e `dashboard-staging-uptime` envelhecem melhor que `2026-05-09`.
* **Um token por integração.** Compartilhar um token entre sistemas torna a revogação uma decisão tudo-ou-nada.
* **Crie com o menor escopo possível.** Um token só de leitura não pode ser convertido em ferramenta de escrita por um atacante.
* **Trate o plaintext como uma senha.** Cole direto no seu gerenciador de segredos; não salve em app de notas, não coloque em `.env` que pode ser commitado por acidente.
* **Audite a lista periodicamente.** Um token com **Último uso: Nunca** há meses é candidato à revogação.

## Usando o token a partir de um script

A API REST do Holter é quem consome estes tokens, mas a superfície da API em si — endpoints, corpos de requisição, formatos de erro, rate limits — tem documentação separada e dedicada. Esta página cobre só a UI de gerenciamento dos tokens; com o token em mãos, consulte a referência da API pra ver como enviá-lo.
