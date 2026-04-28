---
title: Canais de Notificação
description: Crie e gerencie canais de notificação para receber alertas quando monitores mudam de estado.
---

# Canais de Notificação

Um canal de notificação é um destino para onde o Holter envia alertas. Cada canal pertence a um workspace e pode ser vinculado a vários monitores.

## Criando um Canal

1. Clique em **Canais** na barra lateral esquerda.
2. Clique em **Novo Canal**.
3. Preencha os campos abaixo e clique em **Criar Canal**.

## Campos

| Campo | Obrigatório | Descrição |
|-------|-------------|-----------|
| Nome | Sim | Rótulo legível para o canal (ex: "Webhook de Ops"). |
| Tipo | Sim | Um de: `webhook`, `email`. |
| Destino | Sim | O endereço de entrega. Veja o formato esperado por tipo abaixo. |

### Formato do destino por tipo

| Tipo | Formato esperado |
|------|-----------------|
| `webhook` | URL válida `http://` ou `https://`. |
| `email` | Endereço de e-mail válido (ex: `ops@exemplo.com`). |

## Editando um Canal

Clique no nome do canal na lista de Canais (`/delivery/workspaces/{workspace_slug}/channels`) para abrir sua página de configurações em `/delivery/notification-channels/{id}`. Você pode atualizar o nome e o destino. O tipo do canal não pode ser alterado após a criação.

## Logs de Entrega

Cada tentativa de envio de notificação é registrada e pode ser consultada na página de configurações do canal. Clique em **Ver Logs** para abrir a lista de [Logs de Entrega](channel-logs.md), que exibe o resultado de cada envio com filtros por status e intervalo de datas.

Os logs são mantidos por 90 dias.

## Enviando uma Notificação de Teste

Na página de configurações do canal, clique em **Enviar Teste** para enfileirar uma notificação de teste. O payload de teste inclui o nome do canal e um timestamp. Isso é útil para verificar se o destino está acessível antes de vincular o canal a um monitor.

## Assinatura de Webhook

Canais webhook carregam um token de assinatura gerado automaticamente que autentica o Holter perante o seu receptor. Toda entrega de saída é assinada com HMAC-SHA256 e enviada no cabeçalho `X-Holter-Signature` — o segredo nunca trafega na rede.

### Formato do cabeçalho

```
X-Holter-Signature: t=<unix>,v1=<hex>
```

- `t=<unix>`: o timestamp do envio como inteiro Unix.
- `v1=<hex>`: hex em minúsculas de `HMAC-SHA256(token, "<unix>.<body>")`.

O timestamp inicial permite que você rejeite entregas antigas no lado do receptor.

### Verificando uma assinatura

Leia o token de assinatura do canal na página de configurações (veja [Gerenciando o token](#gerenciando-o-token) abaixo); a cada POST recebido:

1. Leia o cabeçalho `X-Holter-Signature` e divida em `t` e `v1`.
2. Opcionalmente rejeite a requisição se `t` estiver mais distante do "agora" do que sua janela de tolerância (5 minutos é um padrão razoável).
3. Calcule `HMAC-SHA256(token, "<t>.<raw_body>")` e codifique em hex minúsculo.
4. Compare em tempo constante com `v1`. Rejeite se não bater.

Exemplos de verificadores:

```js
// Node 18+
import crypto from "node:crypto"

function verify(rawBody, header, token, toleranceSec = 300) {
  const parts = Object.fromEntries(header.split(",").map((p) => p.split("=")))
  const t = Number(parts.t)
  if (!Number.isInteger(t)) return false
  if (Math.abs(Date.now() / 1000 - t) > toleranceSec) return false

  const expected = crypto
    .createHmac("sha256", token)
    .update(`${t}.${rawBody}`)
    .digest("hex")

  return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(parts.v1))
}
```

```python
# Python 3.6+
import hmac, hashlib, time

def verify(raw_body: bytes, header: str, token: str, tolerance_sec: int = 300) -> bool:
    parts = dict(p.split("=", 1) for p in header.split(","))
    try:
        t = int(parts["t"])
    except (KeyError, ValueError):
        return False
    if abs(time.time() - t) > tolerance_sec:
        return False

    signed = f"{t}.".encode() + raw_body
    expected = hmac.new(token.encode(), signed, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, parts.get("v1", ""))
```

```sh
# Verificação rápida pelo shell
printf '%s.%s' "$T" "$BODY" | openssl dgst -sha256 -hmac "$TOKEN"
```

Sempre verifique contra o corpo **bruto** da requisição — JSON reserializado com chaves reordenadas ou espaçamento diferente não vai bater.

### Gerenciando o token

Na página de configurações do canal, a seção **Assinatura de webhook** mostra um botão "Mostrar token de assinatura". Clique para revelar, **Copiar** para copiar o valor para a área de transferência, e **Regenerar** para rotacionar o token.

A rotação é **imediata**: ao confirmar, o token anterior deixa de funcionar no próximo envio. Atualize a cópia armazenada no seu receptor antes de regenerar, ou conte com uma janela curta de verificações que falham até os dois lados baterem.

::: danger Aviso de segurança
O token de assinatura é um segredo compartilhado entre o Holter e seu receptor. Se ele vazar — enviado em texto plano por e-mail, commitado em controle de versão, capturado por um observador não autorizado desta página, etc. —, qualquer pessoa com o valor pode assinar requisições **indistinguíveis das do Holter**. O Holter não consegue detectar tais vazamentos e não há caminho de recuperação além da regeneração.

Você é responsável por proteger o valor depois que ele é gerado. Se suspeitar que o token foi exposto, **regenere imediatamente**.

Se você perder o token (esqueceu de salvá-lo após a criação, perdeu a entrada no gerenciador de senhas, etc.), precisa regenerar — o Holter não guarda o valor em forma recuperável para você; armazena somente como a chave de assinatura viva.

O Holter não aceita responsabilidade por perdas, incidentes ou uso indevido decorrentes de um token de assinatura comprometido ou perdido.
:::

## Código Antiphishing de E-mail

Todo canal de e-mail carrega um código legível gerado automaticamente (ex: `A7K9-X2B3`) tirado de um alfabeto sem ambiguidade (sem `0`/`O`/`1`/`I`/`L`). O código é impresso no rodapé de todos os e-mails que o Holter envia por aquele canal:

```
Verification code: A7K9-X2B3
If you did not expect this email, do not trust messages claiming to be from
Holter that omit this code.
Do not forward this email to anyone you do not trust — the verification code
above is a shared secret that lets the recipient impersonate Holter.
```

Trate o código como um segredo compartilhado que você reconhece de relance: um e-mail se passando pelo Holter que não traga exatamente este código é quase certamente uma tentativa de phishing.

::: warning
**Não encaminhe alertas do Holter para terceiros não confiáveis.** Qualquer pessoa que leia o código de verificação acima pode forjar um e-mail de phishing que passa na sua checagem visual. Se precisar compartilhar um alerta externamente, oculte a linha do código de verificação ou cole apenas o texto relevante do corpo — nunca a mensagem completa incluindo o rodapé.
:::

### Gerenciando o código

Na página de configurações do canal, a seção **Código antiphishing** mostra um botão "Mostrar código antiphishing" mais botões **Copiar** e **Regenerar**.

A rotação é **imediata**: o próximo e-mail que o Holter enviar por este canal já carregará o novo código. Destinatários que memorizaram ou salvaram o código anterior verão o novo no próximo e-mail — treine-os de novo ou avise com antecedência.

::: danger Aviso de segurança
O código antiphishing é um segredo visual compartilhado. Se ele vazar (alertas encaminhados, prints publicados em redes, exfiltração de arquivos de e-mail), qualquer pessoa com o valor pode forjar e-mails de phishing que **passam na checagem visual dos seus destinatários**. O Holter não consegue detectar tais vazamentos e não há caminho de recuperação além da regeneração.

Você é responsável por proteger o código depois que ele é gerado. Se suspeitar de exposição, **regenere imediatamente**.

Se você perder o controle do código atual, regenere — o próximo e-mail carregará o novo valor e você pode treinar os destinatários nele.

O Holter não aceita responsabilidade por perdas, incidentes ou suplantação por phishing decorrentes de um código antiphishing comprometido ou perdido.
:::

## Verificação de Endereço de E-mail

Todo canal de e-mail precisa verificar o endereço de destino antes que a Holter entregue qualquer alerta por ele. Sem essa verificação, um membro do workspace poderia criar um canal apontando para a caixa de entrada de outra pessoa e usar a Holter para enviar testes ou alertas para lá.

### Como funciona

1. Ao criar um canal de e-mail, a Holter envia um e-mail de verificação a partir do endereço institucional para o destino. O link expira em 48 horas.
2. O destinatário clica no link e cai em uma página de confirmação. O endereço passa a aparecer como **Verificado** na página do canal.
3. Enquanto a verificação não acontecer, alertas para esse endereço são descartados na camada de entrega. O canal segue entregando para **destinatários em CC verificados**; se nenhum endereço do canal estiver verificado, a entrega é cancelada e registrada nos [logs de entrega](channel-logs.md) com o motivo `no_verified_recipients`.

### Reenviando a verificação

Abra a página do canal. Logo abaixo do nome, a seção **Verificação do e-mail principal** mostra o estado atual:

- **Verificado** — os alertas serão entregues nesse endereço.
- **Verificação pendente** — os alertas não serão entregues. Clique em **Reenviar verificação** para gerar um novo e-mail; o link anterior é invalidado.

::: danger Aviso de segurança
A verificação só comprova que *alguém com acesso à caixa de entrada* clicou no link. Ela **não** prova que o endereço pertence ao workspace, à equipe ou a uma pessoa específica. Trate canais de e-mail como entrega "melhor esforço": qualquer pessoa que estiver com a caixa aberta naquele momento começa a receber alertas.

Se um destinatário sai da equipe ou perde acesso à caixa, **exclua o canal ou troque o endereço e verifique de novo** — a Holter não tem como invalidar a verificação automaticamente.
:::

## Excluindo um Canal

Na página de lista de canais, clique em **Excluir** ao lado do canal. Isso remove o canal e todos os vínculos com monitores. Monitores vinculados a um canal excluído não receberão mais notificações por aquele canal.

## Vinculando Canais a Monitores

Os canais gerenciam o vínculo com os monitores. Para conectar um canal a um ou mais monitores:

1. Abra a página de configurações do canal.
2. Na seção **Monitores Vinculados**, marque cada monitor que deve disparar notificações por este canal.
3. Clique em **Salvar Alterações**.

Desmarcar um monitor e salvar interrompe imediatamente as notificações futuras daquele monitor por este canal.

Você também pode gerenciar os vínculos via API — inclua um array `notification_channel_ids` no corpo da requisição de criação ou atualização do monitor.

## Formato do Payload

Quando um monitor cai ou se recupera, o Holter envia o seguinte payload JSON para canais webhook:

```json
{
  "version": "1",
  "event": "monitor_down",
  "timestamp": "2026-04-20T10:00:00Z",
  "monitor": {
    "id": "...",
    "url": "https://exemplo.com",
    "method": "get"
  },
  "incident": {
    "id": "...",
    "type": "downtime",
    "started_at": "2026-04-20T10:00:00Z",
    "resolved_at": null
  }
}
```

Eventos: `monitor_down`, `monitor_up`. Para incidentes de expiração de SSL, o evento é `ssl_expiry_down` / `ssl_expiry_up`.

## Relacionado

- [Módulo de Monitoramento](../monitoring/index.md) — incidentes que disparam a entrega
- [Referência da API](../../api/openapi.yml) — endpoints REST para canais de notificação
