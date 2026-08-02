[English](README.md) · [Português](README.pt-BR.md) · **Español** · [简体中文](README.zh-CN.md)

# delegate

Una skill de Claude Code que convierte un prompt desordenado en un briefing limpio, elige
el nivel de profundidad adecuado y el agente más barato capaz de hacer el trabajo, lo
despacha y te muestra cuánto costó.

El punto no es "lanzar un subagente". Claude Code ya hace eso. El punto es que delegar de
forma ingenua es *caro* — un subagente reenvía todo su system prompt y todo el bloque de
esquemas de herramientas en cada turno — y esta skill hace que el camino barato sea el
camino por defecto.

```
tú:       /delegate el redirect de login se rompió tras el refactor de sesión

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

## Qué hace realmente

| | |
|---|---|
| **Rechaza el trabajo barato** | El paso 0 pregunta si delegar vale la pena. Una edición de 10 líneas cuesta más delegada que hecha en el momento — la skill lo dice y simplemente la hace. |
| **Reescribe el prompt** | El subagente tiene cero contexto de la conversación. Tu prompt se convierte en un briefing corto y autosuficiente, con las rutas de los archivos ya nombradas, porque un briefing vago cuesta mucho más en un subagente que en tu sesión. |
| **Enruta por profundidad, no por modelo** | Tres niveles — `trivial` / `standard` / `deep`. El modelo queda fijo; lo que cambia es el esfuerzo de razonamiento. |
| **Elige un agente estrecho** | `general-purpose`, `Explore` y `Plan` cargan todos los servidores MCP que tengas conectados, reenviados en cada turno. Los incluidos `delegate-scout` / `delegate-worker` / `delegate-deep` no cargan ninguno. |
| **Elimina MCP por completo en la ruta A** | `claude -p --strict-mcp-config` carga cero servidores MCP: medidos 17,1k de contexto por turno frente a 44,0k con la configuración por defecto. |
| **Retiene la shell** | Un subproceso no puede mostrar un aviso de permiso, así que el subagente no recibe `Bash`. Devuelve los comandos que quiere ejecutar y *tu* sesión los ejecuta, donde los permisos sí funcionan. |
| **Imprime la cuenta** | Cada ejecución cierra con una ficha: tokens, turnos, coste frente al presupuesto, tiempo. Así ves qué ruta es realmente más barata en vez de adivinar. |

## Instalación

Requiere [Claude Code](https://claude.com/claude-code).

```bash
git clone https://github.com/ocauapaz/claude-delegate.git
cd claude-delegate
./install.sh
```

`./install.sh --project` instala en `./.claude` del repositorio actual en lugar de
`~/.claude`, si solo la quieres en un proyecto.

<details>
<summary>Windows PowerShell (sin bash)</summary>

```powershell
git clone https://github.com/ocauapaz/claude-delegate.git
cd claude-delegate
New-Item -ItemType Directory -Force "$HOME\.claude\skills","$HOME\.claude\agents"
Copy-Item -Recurse -Force .\skills\delegate "$HOME\.claude\skills\"
Copy-Item -Force .\agents\delegate-*.md "$HOME\.claude\agents\"
```

</details>

<details>
<summary>Manual — sin git</summary>

Descarga el repositorio como zip y copia:

- `skills/delegate/` → `~/.claude/skills/delegate/`
- `agents/delegate-*.md` → `~/.claude/agents/`

</details>

Reinicia Claude Code después para que detecte la nueva skill y los agentes.

## Uso

```
/delegate <lo que ibas a escribir>
```

También se activa con frases normales — "pásalo a un subagente", "que lo haga un agent".

Nada más que aprender. La skill decide el nivel, el agente y la ruta; tú lees el bloque de
despacho antes de que corra y la ficha de ejecución después.

Si el resultado vuelve flojo, dilo — la skill redespacha un nivel más arriba con la salida
del fallo pegada en el briefing.

## Configuración

Dos perillas, ambas dentro de `skills/delegate/SKILL.md`:

- **Modelo por defecto** (tabla del paso 2) — viene como `opus`, con `haiku` para el nivel
  `trivial`. Cámbialo si tu plan o presupuesto es otro; al resto de la skill le da igual qué
  modelo nombre.
- **`--max-budget-usd`** (paso 4) — viene como `2`, un techo duro en la ruta A. Súbelo para
  trabajo profundo, bájalo si quieres correa corta.

Las tres definiciones de agente en `agents/` también son markdown plano — ajusta su
`effort`, sus `tools` o sus instrucciones a tu gusto.

## Rutas

**Ruta A — `claude -p`.** Preferida. Una perilla real de `--effort`, cero esquemas MCP, un
techo en dólares y JSON estructurado de vuelta con los datos completos de uso. Requiere que
`claude auth status` responda `"loggedIn": true`; si no, ejecuta `claude setup-token` una vez.

**Ruta B — la herramienta `Agent`.** Alternativa. Sin parámetro de esfuerzo (la skill inyecta
una línea de profundidad en el prompt) y sin datos de uso, así que la ficha reporta
`cost: n/a (route B)` en vez de adivinar.

## Estructura

```
skills/delegate/SKILL.md    la skill
agents/delegate-scout.md    investigador de solo lectura   (Read, Grep, Glob, Bash)
agents/delegate-worker.md   implementador acotado          (+ Edit, Write)
agents/delegate-deep.md     implementador de alto esfuerzo (+ Edit, Write, más razonamiento)
install.sh
```

## Licencia

MIT
