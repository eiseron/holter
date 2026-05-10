---
title: Configurações
description: Configuração de usuário e workspace no Holter.
---

# Configurações

O Holter divide as configurações em uma página por conta e páginas por workspace:

| Página | Onde encontrar | Quem pode editar |
|--------|----------------|-------------------|
| [Usuário](user.md) | **Minha conta** na barra lateral do workspace | O próprio usuário |
| [Workspace](workspace.md) | **Configurações** na barra lateral do workspace | Membros com papel `Owner` ou `Admin` |
| [Tokens da API](api-tokens.md) | **Tokens da API** na barra lateral do workspace | Apenas `Owner` (admins podem ver) |

Cada página vive no topo do seu próprio recurso:

- A página de usuário fica em `/identity/user/{user-id}` e independe de qualquer workspace.
- A página de um workspace fica em `/identity/workspaces/{slug-do-workspace}` e se aplica àquele workspace específico.
- A página de tokens da API fica em `/identity/workspaces/{slug-do-workspace}/api-tokens`.

A página de usuário lista todos os workspaces a que você pertence, então é possível pular direto para as configurações de um workspace sem voltar pela dashboard. Em qualquer página de configurações, a navegação interna mostra a sua conta e uma entrada por workspace que você administra, então dá pra alternar entre contextos administrativos em um clique.
