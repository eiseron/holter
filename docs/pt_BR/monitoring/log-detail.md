# Detalhe do Log

A página de Detalhe do Log exibe as evidências completas capturadas durante uma única execução de verificação.

## Acessando a Página

Clique em **Ver Detalhes** em qualquer linha nos [Logs Técnicos](logs.md) ou navegue para `/monitoring/logs/{log_id}`.

## Cabeçalho

O cabeçalho exibe:

- **Badge de status** — o resultado da verificação (UP, DOWN, DEGRADED, etc.)
- **Latência** — tempo de resposta em milissegundos
- **Região** — o datacenter de onde a verificação foi executada
- **Verificado em** — timestamp exato da verificação

## Cadeia de Redirecionamentos

Quando o monitor está configurado para seguir redirecionamentos e o servidor redirecionou a requisição, uma lista numerada mostra cada salto:

| Campo | Descrição |
|-------|-----------|
| URL | A URL neste salto |
| Endereço IP | O endereço IP resolvido |
| Código de Status | Código de status HTTP retornado neste salto |

A entrada final é a resposta de destino.

## Mensagem de Erro

Se a verificação falhou com um erro de rede (ex.: conexão recusada, falha de DNS, timeout) ou um erro HTTP inesperado, a mensagem de erro é exibida aqui.

## Headers da Resposta

Os cabeçalhos HTTP de resposta retornados pelo servidor, formatados como um objeto JSON.

## Trecho do Conteúdo

A primeira parte do corpo da resposta (até 100 KB). Se o corpo for um JSON válido, é formatado para facilitar a leitura; caso contrário, é exibido como texto simples.

## Snapshot de Configuração do Monitor

A configuração do monitor no momento da verificação (URL, método, timeout, palavras-chave, etc.). Este snapshot é imutável — alterar as configurações do monitor posteriormente não altera as entradas de log históricas.

## Evidências Herdadas

Quando o corpo da resposta é idêntico ao da verificação imediatamente anterior, o sistema registra a evidência uma vez e marca os logs subsequentes como herdados. Um aviso de **Evidências herdadas** aparece com um link para a entrada de log original onde o conteúdo completo está armazenado. Isso reduz o armazenamento sem perder nenhuma informação.
