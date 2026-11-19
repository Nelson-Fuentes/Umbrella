# SDD Umbrella — fuentes rulesync

Metodologia SDD Umbrella (v8) mantenida como fuente unica en `.rulesync/` y
generada con [rulesync](https://github.com/dyoshikawa/rulesync) para todos los
agentes que soporte (`--targets '*'`), con empaquetado dedicado para Claude
Code y Google Antigravity.

El contenido original (formato nativo de Antigravity) vive sin tocar en
[`vendor/antigravity-plugin-source/`](vendor/antigravity-plugin-source) y se
convirtio una sola vez a `.rulesync/` con `scripts/convert_source.py`. Edita
`.rulesync/` de aqui en adelante; el conversor es para referencia, no corre en
cada build.

## Requisitos

- Node.js y npm (para `rulesync`, fijado en `package.json` sin rango de version).
- Python 3 (para los scripts de validacion y la matriz de soporte).

## Build

```bash
npm ci
./build.sh
```

Esto genera:

- `dist/project/` — salida de proyecto para todos los targets que rulesync
  soporte en la version fijada (`--targets '*' --features '*'`).
- `dist/claude/plugins/umbrella/` — plugin `claudecode-plugin`
  (`mcp,commands,subagents,skills,hooks`; Claude Code no soporta `rules` en
  formato de plugin, asi que las reglas se copian como referencia en
  `docs/rules/`).
- `dist/claude/.claude-plugin/marketplace.json` — marketplace local
  (`umbrella-local`) que apunta a `./plugins/umbrella`, para que Claude Code
  instale el plugin con `claude plugin install` en vez de copiar archivos
  sueltos a `.claude/`.
- `dist/antigravity/umbrella/` — plugin `antigravity-plugin`
  (`rules,mcp,subagents,skills,hooks`).
- `docs/soporte-por-agente.md` — tabla agente x feature, derivada en cada
  build de la tabla de capacidades que el rulesync instalado reporta.

`build.sh` no instala nada por su cuenta: usa `node_modules/.bin/rulesync`
(sobreescribible con la variable `RULESYNC`) y falla con un mensaje claro si
`npm ci` no se corrio antes.

## Instalar en una maquina

Tras una build, copia el resultado a los agentes detectados en el equipo:

```bash
./scripts/install.sh [ruta-del-proyecto]
```

En Windows: `./scripts/install.ps1 [-TargetDir <ruta>]`.

- **Claude Code** se instala como plugin real, no copiando archivos: si el
  comando `claude` esta en el `PATH`, el script ofrece `claudecode` (scope
  `project`) y `claudecode-global` (scope `user`).
  - `claudecode` registra el marketplace directamente desde `dist/claude/`
    del repo (`claude plugin marketplace add dist/claude --scope project`
    + `claude plugin install umbrella@umbrella-local --scope project`).
  - `claudecode-global` primero copia `dist/claude/` a una ruta estable
    fuera del repo (`~/.local/share/umbrella-sdd/claude-plugin/`) y
    registra el marketplace desde ahi con `--scope user`, para que el
    plugin siga disponible en cualquier proyecto de la maquina aunque
    esta carpeta se mueva o se borre despues. Se puede reinstalar
    (`claudecode-global` de nuevo) para refrescar esa copia tras una
    build nueva.
- El resto de agentes (`cursor`, `antigravity`, `antigravity-global`,
  `copilot`, `codexcli`, `opencode`) se detectan por la presencia de sus
  directorios (`.cursor`, `.agents`, `~/.gemini`, ...) y se instalan copiando
  `dist/project/`; nunca sobrescriben un archivo existente sin confirmacion.

## Verificar antes de asumir nombres de targets/features

```bash
npx --no-install rulesync generate --help
npx --no-install rulesync docs reference/supported-tools
```

La version de rulesync esta fijada (sin `^`) en `package.json`; si se
actualiza, vuelve a correr lo anterior antes de tocar `rulesync.jsonc`.

## CI

`.github/workflows/build.yml` corre `npm ci && ./build.sh` en cada push/PR y
publica `dist/` y `docs/soporte-por-agente.md` como artifact.
