---
title: Esqueci minha senha
description: Recupere o acesso à sua conta no Holter com um link de redefinição enviado por e-mail.
---

# Esqueci minha senha

Se você esqueceu sua senha, o Holter envia um link de redefinição para o e-mail cadastrado. O link tem validade curta e só pode ser usado uma vez.

## Solicitando a redefinição

1. Acesse `/identity/login` e clique em **Esqueci minha senha**.
2. Informe o e-mail da sua conta.
3. Clique em **Enviar instruções**.

Independentemente do e-mail informado existir ou não, a tela responde com a mesma mensagem neutra — *"Se este e-mail existir, você receberá instruções."* Isso é proposital: impede que um atacante descubra se um endereço específico está cadastrado.

## O e-mail e o link

Se o e-mail informado pertence a uma conta, você recebe um e-mail com o assunto **"Redefinição de senha do Holter"** e um link no formato `/identity/reset-password/<token>`. O link:

- expira em **15 minutos**;
- é de **uso único** — após uma redefinição bem-sucedida, qualquer nova tentativa com o mesmo link é rejeitada;
- continua válido para o **link mais recente** caso você peça uma nova solicitação (ainda assim, dentro da janela de 15 minutos).

Se o link expirar ou já tiver sido usado, o sistema te leva de volta a `/identity/forgot-password` com a mensagem *"Este link de redefinição é inválido ou expirou."* — basta solicitar uma nova redefinição.

## Definindo a nova senha

Ao abrir o link você cai no formulário **Definir nova senha**. A nova senha precisa atender à mesma política do cadastro: pelo menos 12 caracteres, com letra maiúscula, letra minúscula e dígito. O campo de confirmação precisa ser idêntico ao primeiro.

Quando você confirma:

1. A senha é hasheada (Argon2ID com pepper do servidor) e gravada na sua conta.
2. **Todas as sessões ativas em outros dispositivos são revogadas** — qualquer aba aberta em outro navegador é desconectada na próxima requisição. Esta é a "Soberania da Sessão": trocar a senha invalida tudo o que veio antes dela.
3. Você é redirecionado para `/identity/login` com a mensagem *"Sua senha foi atualizada. Entre com a nova senha."*
4. Um e-mail de alerta de segurança chega à sua caixa com o assunto **"Sua senha foi alterada"**, descrevendo a revogação de sessões e orientando o que fazer caso a alteração não tenha sido feita por você.

## Notas de segurança

- O token salvo no banco é um **hash SHA-256 do plaintext** — o servidor nunca persiste o plaintext do link.
- Uma senha fraca **não consome** o token: você pode tentar de novo no mesmo link enquanto ele estiver dentro da janela de 15 minutos.
- O e-mail de alerta após a troca é a sua chance de detectar uma alteração indevida. Se você receber este e-mail sem ter solicitado uma redefinição, troque a senha imediatamente e entre em contato com o suporte.

## Próximos passos

- [Login](sign-in.md)
- [Verificação de e-mail](email-verification.md)
