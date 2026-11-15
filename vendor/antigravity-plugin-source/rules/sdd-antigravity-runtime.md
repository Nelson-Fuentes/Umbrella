---
trigger: always_on
description: "Cómo ejecutar las skills y subagentes sdd-* de la metodología SDD Umbrella dentro de Antigravity: invocación de subagentes, equivalencia de herramientas, archivos de reglas y comandos de Spec Kit."
---

# SDD Umbrella en Antigravity

Las skills `sdd-*` se escribieron con nombres genéricos de herramientas. En Antigravity se ejecutan así.

## 1. Subagentes y Optimización por Lotes (Batching)
- "Lanzar `sdd-x`", "con `sdd-x`" o "`sdd-x` (`operación`)" significa: llamar a la herramienta `invoke_subagent` con el subagente personalizado `sdd-x` (definido en `agents/sdd-x.md` del plugin), pasándole en el prompt la operación (o lote de operaciones) y TODOS sus parámetros. El subagente arranca con contexto limpio: no ve esta conversación.
- **Optimización obligatoria por lotes (Batching):** Para evitar tiempos prolongados y consumo excesivo de tokens por invocaciones repetitivas, está PROHIBIDO invocar subagentes en bucle para tareas que pueden consolidarse. Se DEBE agrupar todo el trabajo relacionado en una sola invocación por subagente:
  - `sdd-git-reader`: consolida TODAS las lecturas y verificaciones de la fase en una sola llamada inicial (ej: `estado-repos` + `rama` + `issue` + `pr` de todos los repos implicados) y una sola llamada final de comprobación. Prohibido llamar a `sdd-git-reader` de forma fragmentada para consultar un dato a la vez.
  - `sdd-git-operator`: encadena en UNA SOLA invocación todas las operaciones de git de la fase (`checkout`, `commit`(s), `push`, `actualizar-puntero`, `eliminar-rama`) para los repositorios afectados.
  - `sdd-context-scout`: analiza en UNA SOLA invocación todo el contexto requerido (Vault, reglas y grafos de todos los submódulos involucrados), consolidando las necesidades en un solo prompt completo en vez de lanzar scouts sucesivos o fragmentados.
  - `sdd-issue-manager`: procesa la creación de múltiples issues en un solo lote (`crear-lote`), y encadena en la misma llamada todas las operaciones necesarias (crear, mover estados de issues relacionados, comentar y marcar casillas).
  - `sdd-poker-estimator`: para estimar tareas en `sdd-plan-close`, se lanzan 3 subagentes en paralelo por issue (Desarrollo, Arquitectura, Pruebas) evaluando sus respectivas perspectivas.
- "En paralelo" significa varias llamadas a `invoke_subagent` seguidas (como los 3 estimadores de póker de un issue), sin esperar el resultado de la anterior.
- Espacio de trabajo del subagente: `inherit` (mismo workspace). Nunca `branch` (worktree aislado): las ramas las gestiona solo `sdd-git-operator`.
- Si el entorno no ofrece subagentes personalizados (por ejemplo, una versión del IDE sin `invoke_subagent` para agentes propios):
  1. Usar `invoke_subagent` con el subagente `self`, inyectando al inicio del prompt el contenido completo de `agents/sdd-x.md` (sin el frontmatter) y después la operación y sus parámetros.
  2. Si no hay ninguna herramienta de subagentes, DETENERSE e informarlo al usuario. No ejecutar `git`, `gh` ni el MCP de GitHub desde el agente principal como atajo.

## 2. Agente principal: git y GitHub
El agente principal no ejecuta `git`, `gh` ni el MCP de GitHub con `run_command` ni con ninguna otra herramienta. Lee con `sdd-git-reader` y escribe con `sdd-git-operator`, `sdd-issue-manager`, `sdd-pr-manager`, `sdd-release-manager` o `sdd-github-setup`. Única excepción: los comandos de Spec Kit, que pueden crear o cambiar ramas por el preset.

## 3. Equivalencia de herramientas
| En las skills | En Antigravity |
|---|---|
| Read / leer un archivo | `view_file` |
| Glob / buscar archivos | `find_by_name`, `list_dir` |
| Grep | `grep_search` |
| Bash / ejecutar un comando | `run_command` |
| Write / crear un archivo | `write_to_file` |
| Edit / modificar un archivo | `replace_file_content`, `multi_replace_file_content` |

Las ediciones de código y de notas se hacen SIEMPRE con estas herramientas nativas, nunca con scripts que sobrescriban archivos.

## 4. Archivos de reglas del proyecto
- Donde las skills dicen `CLAUDE.md`, Antigravity lee `.agents/AGENTS.md` (y `AGENTS.md`). Ambos llevan el mismo contenido de reglas: al escribir o actualizar uno, actualizar el otro en el mismo paso.
- Leer el `.agents/AGENTS.md` (o `CLAUDE.md`) del submódulo afectado cuando una skill pida el `CLAUDE.md` del submódulo.

## 5. Spec Kit
- Spec Kit se instala con la integración de Antigravity: `specify init . --integration agy` (proyecto nuevo) o `specify integration install agy` (proyecto existente). Sus comandos quedan como skills en `.agents/skills/speckit-<comando>/`.
- Donde las skills dicen `/speckit.<comando>`, ejecutar la skill `speckit-<comando>` (slash `/speckit-<comando>`). Antes, comprobar con `specify --help` la sintaxis de la versión instalada.

## 6. Confirmaciones
Toda escritura (git, GitHub, Vault, spec) requiere confirmación explícita del usuario en el chat ANTES de invocar al subagente que la ejecuta. Los subagentes no piden confirmación: ejecutan lo que se les pasa.
