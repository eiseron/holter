---
title: Conectar um Provedor
description: Como conectar e desconectar um provedor externo nas integrações do Holter.
---

# Conectar um Provedor

## Navegar pelo Catálogo

Acesse **Integrações → Novo** dentro do seu workspace. Os provedores são agrupados por categoria (Anúncios, Notificações, Rastreamento de Issues, Página de Status, Calendário). Cada card mostra o nome do provedor, uma breve descrição e o status atual da conexão.

Se o plano do seu workspace não inclui um provedor, o card exibe o badge "Upgrade necessário" e o botão de conectar fica desabilitado.

## Conectando

1. Clique em **Conectar** no card do provedor.
2. Você é redirecionado para a página de autorização do provedor.
3. Autorize o Holter a agir em seu nome.
4. Após a autorização, você é redirecionado de volta ao Holter e a integração é criada com o status **Ativo**.

A autorização utiliza OAuth 2.0. O Holter armazena apenas o token de acesso (criptografado em repouso) — nunca armazena sua senha do provedor.

## Reconectando

Se o status da integração passar a ser **Reautenticação necessária**, o token de acesso foi revogado ou expirou e não pode ser renovado automaticamente. Clique em **Reconectar** para passar pelo fluxo OAuth novamente.

## Desconectando

1. Abra a integração na lista de Integrações.
2. Clique em **Desconectar** no final da página.
3. O Holter revoga o token no provedor e remove a integração.

Desconectar exclui todas as regras associadas à integração. As entradas do log de atividade são mantidas para fins de auditoria.

## Relacionado

- [Regras de Automação](rules.md) — configure ações após conectar
- [Log de Atividade](activity-log.md) — veja o que o Holter disparou
