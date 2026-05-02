---
title: Verificação de E-mail
description: Ative sua conta Holter clicando no link enviado para sua caixa de entrada.
---

# Verificação de E-mail

Após o cadastro, o Holter envia um e-mail de verificação para o endereço da conta. O link dentro desse e-mail é a única forma de ativar a conta.

## Verificando Seu E-mail

1. Abra o e-mail de `noreply@holter.dev` com o assunto "Verify your Holter account".
2. Clique no link de verificação no corpo da mensagem.
3. O Holter ativa a conta e redireciona você para `/identity/login` com uma mensagem de confirmação.

## Comportamento do Link

- O link é de uso único. Clicar nele uma segunda vez falha com erro neutro.
- O link expira em 1 hora a partir do cadastro. Quando expirado, você verá o mesmo erro neutro.
- O link é vinculado ao usuário que o solicitou; não é possível compartilhá-lo para verificar o e-mail de outra pessoa.

Se você não solicitou uma conta no Holter mas recebeu o e-mail de verificação, pode ignorá-lo com segurança. Sem o seu clique, nenhuma conta é ativada.

## Solução de Problemas

- **"Este link de verificação é inválido ou expirou."** — ou o link já foi usado, ou mais de uma hora se passou. Cadastre-se novamente com o mesmo e-mail; esse comportamento é intencional para manter a janela de verificação curta.
