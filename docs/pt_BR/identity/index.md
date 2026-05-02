---
title: Identidade
description: Conta, cadastro, login e verificação de e-mail no Holter.
---

# Módulo Identidade

O módulo de identidade controla como você cria uma conta no Holter, comprova que um endereço de e-mail é seu e mantém sua sessão ativa no painel. Cada workspace, monitor e canal de notificação pertence a uma identidade deste módulo.

## Páginas

| Página | Descrição |
|--------|-----------|
| [Cadastro](sign-up.md) | Crie sua conta, aceite os termos e dispare o e-mail de verificação |
| [Verificação de E-mail](email-verification.md) | Ative sua conta clicando no link enviado para sua caixa de entrada |
| [Login](sign-in.md) | Autentique-se com e-mail e senha e chegue ao painel do workspace |

## Estados da Conta

Cada conta possui um campo `onboarding_status` que controla o que você pode fazer:

- **pending_verification** — a conta foi criada mas o e-mail ainda não foi verificado. Você consegue fazer login mas não consegue acessar o painel do workspace.
- **active** — o e-mail está verificado, o painel está acessível e monitores e canais podem ser criados.
- **pending_billing** — reservado para planos pagos futuros.
- **banned** — bloqueio administrativo. Todas as sessões são revogadas imediatamente e o login é rejeitado.

## Vínculo com Workspace

Ao se cadastrar você recebe automaticamente um workspace padrão e é vinculado a ele com o papel `owner`. Iterações futuras permitirão convidar outros usuários; o modelo de junção já suporta os papéis `owner | admin | member`. Veja a [visão geral de Monitoramento](../monitoring/index.md) para entender o que um workspace contém.

## Notas de Segurança

- Senhas são protegidas com Argon2ID combinado com um *pepper* do servidor, de modo que um vazamento de banco sozinho não é suficiente para quebrar senhas offline.
- Sessões são tokens aleatórios cujo digest SHA-256 é a única coisa armazenada; cookies são `HTTP-Only` e `SameSite: Lax`, defendendo contra CSRF e roubo via JavaScript.
- Links de verificação são de uso único e expiram rapidamente. Clicar duas vezes no mesmo link falha na segunda tentativa com uma mensagem neutra.
