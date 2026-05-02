---
title: Cadastro
description: Como criar uma conta no Holter.
---

# Cadastro

Criar uma conta é o primeiro passo antes de configurar monitores ou canais de notificação.

## Criando Sua Conta

1. Acesse `/identity/new`.
2. Informe o e-mail que você usará para login.
3. Escolha uma senha forte. A política mínima é 12 caracteres com pelo menos uma letra minúscula, uma maiúscula e um dígito.
4. Marque **Li e concordo com os Termos de Uso e a Política de Privacidade**. O formulário só envia com o consentimento explícito.
5. Clique em **Criar conta**.

Quando o formulário é aceito você é redirecionado para a página de login com uma mensagem pedindo para verificar seu e-mail. Até a verificação a conta fica em `pending_verification` e o painel do workspace não fica acessível.

## O Que Acontece nos Bastidores

- Um novo usuário é criado com `onboarding_status: pending_verification`.
- Um workspace padrão é criado e você se torna `owner` dele.
- Um e-mail de verificação é enviado para o endereço informado.
- O instante exato em que você aceitou os termos é registrado para replay em revisão jurídica.

## Se o E-mail Não Chegar

Verifique a pasta de spam primeiro. Se mesmo assim não chegar, entre em contato com o suporte — o reenvio automático chegará em uma versão futura.

## Próximos Passos

- [Verifique seu e-mail](email-verification.md)
- [Faça login](sign-in.md)
