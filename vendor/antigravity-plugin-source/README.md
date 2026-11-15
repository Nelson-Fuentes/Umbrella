# SDD Umbrella para Antigravity

Plugin de Google Antigravity con la metodología SDD Umbrella (v8): 10 skills, 11 subagentes y 2 reglas.

## Contenido

```
sdd-umbrella/
├── plugin.json                       Manifiesto del plugin
├── skills/                           Skills (se invocan solas o con /<nombre>)
│   ├── sdd-init/                     Inicializar proyecto NUEVO o LEGACY
│   ├── sdd-specify/                  specify + clarify (USR, RFR, HFR)
│   ├── sdd-specify-close/            Cierre de especificación, issues PL
│   ├── sdd-plan/                     Plan por especificación
│   ├── sdd-plan-close/               tasks + analyze, PR, issues TK, Vault a approved
│   ├── sdd-implement/                Implementar un TK
│   ├── sdd-implement-close/          Commit, grafo, Vault, PR y estados del TK
│   ├── sdd-sprint-close/             develop → release → main con tags y notas
│   ├── sdd-fix-release/              Tag y release de un fix ya fusionado
│   └── sdd-cleanup/                  Auditar y eliminar ramas residuales/anómalas
├── agents/                           Subagentes (invoke_subagent)
│   ├── sdd-context-scout.md          Lectura de Vault y grafos
│   ├── sdd-legacy-analyzer.md        Análisis de submódulo legacy + Graphify
│   ├── sdd-poker-estimator.md        Estimación Scrum Poker (modelo flash)
│   ├── sdd-code-reviewer.md          Revisión del diff
│   ├── sdd-vault-updater.md          Propuesta de notas del Vault
│   ├── sdd-git-reader.md             Única lectura de git/GitHub
│   ├── sdd-git-operator.md           Única escritura en repos
│   ├── sdd-issue-manager.md          Issues SP/PL/TK y estados
│   ├── sdd-pr-manager.md             PR sin palabras de cierre, merge commit
│   ├── sdd-release-manager.md        Versionado vMM.mm.pp, tags y releases
│   └── sdd-github-setup.md           Proyecto, campos, etiquetas, repo del Vault
├── rules/
│   ├── sdd-antigravity-runtime.md    always_on: cómo correr las skills en Antigravity
│   └── sdd-metodologia-umbrella.md   model_decision: la metodología completa
├── workflows/                        Slash commands opcionales para el IDE
├── install.sh / install.ps1          Instaladores
└── validate.py                       Validador del formato
```

## Instalación

Requisitos: Antigravity App, CLI o IDE con soporte de skills y plugins; `gh` autenticado (o el MCP de GitHub); Python con `pip` (para Graphify).

### Opción A: por proyecto (recomendada)
Queda dentro del repo de especificaciones y se versiona con él, así todo el equipo lo tiene.

```bash
./install.sh --workspace /ruta/al/repo-de-especificaciones --with-workflows
```
Windows: `.\install.ps1 -Workspace C:\ruta\al\repo -WithWorkflows`

Resultado: `<repo>/.agents/plugins/sdd-umbrella/` (y `<repo>/.agents/workflows/sdd-*.md` con `--with-workflows`).

### Opción B: global (App e IDE, todos los proyectos)
```bash
./install.sh --global          # ~/.gemini/config/plugins/sdd-umbrella
```

### Opción C: Antigravity CLI
```bash
./install.sh --cli             # equivale a: agy plugin install <esta carpeta>
```
También puedes subir esta carpeta a un repo de GitHub e instalar con `agy plugin install https://github.com/<dueño>/<repo>`.

### Opción D: sin plugin (si tu versión no carga plugins de workspace)
```bash
./install.sh --flat /ruta/al/repo --with-workflows
```
Copia a `.agents/skills/`, `.agents/agents/` y `.agents/rules/` del proyecto.

Después de instalar, reinicia la sesión del agente. Comprueba en **Customizations** (App/IDE), o con `/plugin list` y `/agents` (CLI), que aparezcan las skills `sdd-*` y los subagentes.

## Uso

1. En el repo de especificaciones: `/sdd-init` (o pide "inicializa el proyecto con SDD Umbrella").
2. Por cada requerimiento o fix: `/sdd-specify` → `/sdd-specify-close` → `/sdd-plan` → `/sdd-plan-close`.
3. Por cada issue TK: `/sdd-implement` → `/sdd-implement-close`.
4. Fin de sprint: `/sdd-sprint-close`. Fix fusionado en `release` o `main`: `/sdd-fix-release`.
5. Mantenimiento y depuración: `/sdd-cleanup` para auditar y purgar ramas locales y remotas residuales o anómalas en los submódulos.

`sdd-init` instala Spec Kit con su integración de Antigravity (`specify init . --integration agy`), que deja los comandos como skills `speckit-*` (`/speckit-specify`, `/speckit-plan`, etc.). Las skills `sdd-*` los invocan por ese nombre.

## Qué cambió respecto de la versión para Claude Code

- **Subagentes:** frontmatter de Antigravity (`tools`, `subagent: true`, `mainAgent: false`, `model`, `commandExecutionPolicy`). Se invocan con `invoke_subagent`; nunca aparecen como agente principal.
- **Herramientas:** Read/Glob/Grep/Bash/Write/Edit → `view_file`, `find_by_name`/`list_dir`, `grep_search`, `run_command`, `write_to_file`, `replace_file_content`/`multi_replace_file_content`.
- **Permisos de comandos:** los subagentes de solo lectura tienen `commandExecutionPolicy: "off"` y no reciben `run_command`; los de git/GitHub y `sdd-legacy-analyzer` usan `auto`, porque necesitan red (push, `gh`, `pip`) y el sandbox la bloquearía.
- **Reglas del proyecto:** Antigravity lee `AGENTS.md`/`.agents/AGENTS.md`, no `CLAUDE.md`. `sdd-init` escribe ambos con el mismo contenido y la regla de runtime obliga a mantenerlos sincronizados.
- **Descripciones entre comillas:** las originales tenían `: ` dentro y un parser YAML estricto las rechaza.
- **Contenido de la metodología:** sin cambios de fondo; solo se agregó a cada skill la línea que apunta a la regla de runtime, y a `sdd-init` la instalación de Spec Kit con `--integration agy`.

## Puntos a verificar en tu instalación

- **Nombres de herramientas** `find_by_name` y `list_dir`: la documentación oficial confirma `view_file`, `grep_search`, `run_command`, `write_to_file` y `replace_file_content`; los otros dos son los nombres habituales del agente de Antigravity. Un nombre inexistente puede colgar al subagente (problema conocido). Si pasa, quítalos de `tools` en los cinco subagentes de lectura y vuelve a correr `python3 validate.py`.
- **Subagentes en el IDE:** la documentación de subagentes personalizados lista App y CLI. Si el IDE no los ofrece, la regla `sdd-antigravity-runtime` indica usar `invoke_subagent` con `self` inyectando el archivo del agente, o detenerse; nunca ejecutar git desde el agente principal.
- **`commandExecutionPolicy: auto`:** confirma que en tu configuración permite `git push` y `gh` con red; si tu organización exige `sandbox`, ajusta los permisos de red del sandbox.

## Validar después de editar
```bash
pip install pyyaml
python3 validate.py
```
