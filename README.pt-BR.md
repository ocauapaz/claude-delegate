[English](README.md) · **Português** · [Español](README.es.md) · [简体中文](README.zh-CN.md)

# delegate

Uma skill do Claude Code que transforma um prompt bagunçado em um briefing limpo, escolhe
o nível de profundidade certo e o agente mais barato capaz de fazer o trabalho, despacha, e
mostra quanto custou.

O ponto não é "criar um subagente". O Claude Code já faz isso. O ponto é que delegar de
forma ingênua é *caro* — um subagente reenvia todo o system prompt e todo o bloco de schema
das ferramentas a cada turno — e esta skill torna o caminho barato o caminho padrão.

```
você:     /delegate o redirect de login quebrou depois do refactor de sessão

claude:   agent:  delegate-deep
          model:  opus
          effort: deep — "Think hard. Trace the full flow before editing..."
          prompt:
          Fix the post-login redirect regression introduced by the session refactor.
          Start at src/auth/session.ts and src/routes/login.tsx. Follow AGENTS.md.
          You have no shell — put validation commands into `commands_to_run`.

          ...

          route:  A (claude -p)
          agent:  delegate-deep · tools Read,Edit,Write,Grep,Glob
          model:  opus · effort high
          tokens: 14 in · 17.2k cache write · 24.2k cache read · 65 out · 7 turns
          cost:   $0.42 of $2.00 budget · 1m 12s
```

## O que ela realmente faz

| | |
|---|---|
| **Recusa trabalho barato** | O passo 0 pergunta se delegar vale a pena. Uma edição de 10 linhas custa mais delegada do que feita ali mesmo — a skill diz isso e simplesmente faz. |
| **Reescreve o prompt** | O subagente tem zero contexto da conversa. Seu prompt vira um briefing curto e autossuficiente, já com os caminhos dos arquivos, porque um briefing vago custa muito mais em um subagente do que na sua sessão. |
| **Roteia por profundidade, não por modelo** | Três níveis — `trivial` / `standard` / `deep`. O modelo fica fixo; o que muda é o esforço de raciocínio. |
| **Escolhe um agente estreito** | `general-purpose`, `Explore` e `Plan` carregam todos os servidores MCP conectados, reenviados a cada turno. Os `delegate-scout` / `delegate-worker` / `delegate-deep` inclusos não carregam nenhum. |
| **Zera o MCP na rota A** | `claude -p --strict-mcp-config` carrega zero servidores MCP: medidos 17,1k de contexto por turno contra 44,0k com a config padrão. |
| **Retém o shell** | Um subprocesso não consegue exibir prompt de permissão, então o subagente não recebe `Bash`. Ele devolve os comandos que quer rodar e *a sua* sessão os executa, onde as permissões funcionam. |
| **Mostra a conta** | Toda execução fecha com um cartão: tokens, turnos, custo contra o orçamento, tempo. Assim dá para ver qual rota é realmente mais barata em vez de adivinhar. |

## Instalação

Requer o [Claude Code](https://claude.com/claude-code).

```bash
git clone https://github.com/ocauapaz/claude-delegate.git
cd claude-delegate
./install.sh
```

`./install.sh --project` instala em `./.claude` do repositório atual em vez de `~/.claude`,
se você quiser a skill em apenas um projeto.

<details>
<summary>Windows PowerShell (sem bash)</summary>

```powershell
git clone https://github.com/ocauapaz/claude-delegate.git
cd claude-delegate
New-Item -ItemType Directory -Force "$HOME\.claude\skills","$HOME\.claude\agents"
Copy-Item -Recurse -Force .\skills\delegate "$HOME\.claude\skills\"
Copy-Item -Force .\agents\delegate-*.md "$HOME\.claude\agents\"
```

</details>

<details>
<summary>Manual — sem git</summary>

Baixe o repositório como zip e copie:

- `skills/delegate/` → `~/.claude/skills/delegate/`
- `agents/delegate-*.md` → `~/.claude/agents/`

</details>

Reinicie o Claude Code depois, para ele reconhecer a nova skill e os agentes.

## Uso

```
/delegate <o que você ia digitar>
```

Também dispara com frases comuns — "manda isso pra um subagente", "põe um agent pra fazer".

Nada mais para aprender. A skill decide o nível, o agente e a rota; você lê o bloco de
despacho antes de rodar e o cartão de execução depois.

Se o retorno vier fraco, diga — a skill redespacha um nível acima com a saída da falha
colada no briefing.

## Configuração

Dois botões, ambos dentro de `skills/delegate/SKILL.md`:

- **Modelo padrão** (tabela do passo 2) — vem como `opus`, com `haiku` no nível `trivial`.
  Mude se seu plano ou orçamento for outro; o resto da skill não se importa com o nome do
  modelo.
- **`--max-budget-usd`** (passo 4) — vem como `2`, um teto rígido na rota A. Aumente para
  trabalho profundo, reduza se quiser rédea curta.

As três definições de agente em `agents/` também são markdown puro — ajuste `effort`,
`tools` ou as instruções como quiser.

## Rotas

**Rota A — `claude -p`.** Preferida. Um controle real de `--effort`, zero schemas MCP, teto
em dólares e JSON estruturado de volta, com os dados completos de uso. Exige que
`claude auth status` responda `"loggedIn": true`; se não, rode `claude setup-token` uma vez.

**Rota B — a ferramenta `Agent`.** Fallback. Sem parâmetro de esforço (a skill injeta uma
linha de profundidade no prompt) e sem dados de uso, então o cartão reporta
`cost: n/a (route B)` em vez de chutar.

## Estrutura

```
skills/delegate/SKILL.md    a skill
agents/delegate-scout.md    investigador somente leitura   (Read, Grep, Glob, Bash)
agents/delegate-worker.md   implementador com escopo       (+ Edit, Write)
agents/delegate-deep.md     implementador de alto esforço  (+ Edit, Write, mais raciocínio)
install.sh
```

## Licença

MIT
