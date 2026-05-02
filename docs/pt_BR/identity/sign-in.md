---
title: Login
description: Autentique-se no Holter com e-mail e senha.
---

# Login

Uma vez verificada a conta, você pode entrar a qualquer momento.

## Entrando

1. Acesse `/identity/login`.
2. Informe o e-mail usado no cadastro.
3. Informe sua senha.
4. Clique em **Entrar**.

Em caso de sucesso o Holter leva você à lista de monitores do seu workspace padrão. Se antes do login você tentou acessar uma página específica, o redirecionamento pós-login te leva de volta para ela.

## Falha de Login

Senha errada e e-mail desconhecido produzem a mesma mensagem neutra — *Invalid email or password.* — e o mesmo tempo de resposta. Isso é proposital: impede que um atacante descubra se um e-mail específico está cadastrado.

## Sessões de Login

Um login bem-sucedido grava um token aleatório de sessão em um cookie HTTP-Only. O token é renovado conforme você usa o painel, evitando logouts automáticos abruptos durante o uso ativo. Sair pela opção no menu superior remove imediatamente o token no servidor.

## Conta Banida

Uma conta `banned` é rejeitada com a mesma mensagem neutra. Se você acredita que isso é um engano, fale com o suporte.

## Próximos Passos

- [Painel do workspace](../monitoring/dashboard.md)
- [Canais de notificação](../delivery/notification-channels.md)
