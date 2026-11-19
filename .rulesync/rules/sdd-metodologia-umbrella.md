---
root: false
targets: ["*"]
description: "Metodología SDD Umbrella (v8): repos (raíz de especificaciones, Vault, submódulos de código), roles, issues SP/PL/TK, Vault y Graphify, flujo del sprint, semaforización y hotfix. Leer cuando se trabaje con las skills sdd-*, con Spec Kit, con el Vault o con issues y ramas del proyecto."
globs: ["**/*"]
antigravity:
  trigger: model_decision
  description: "Metodología SDD Umbrella (v8): repos (raíz de especificaciones, Vault, submódulos de código), roles, issues SP/PL/TK, Vault y Graphify, flujo del sprint, semaforización y hotfix. Leer cuando se trabaje con las skills sdd-*, con Spec Kit, con el Vault o con issues y ramas del proyecto."
---

# Metodología SDD Umbrella (v8)

Metodología de ingeniería de software agnóstica de tecnología. Combina un repo paraguas de especificaciones, un Vault de Obsidian como memoria del proyecto, grafos de código con Graphify, Spec Kit para el desarrollo basado en especificaciones y Antigravity para la implementación.

## 1. Repositorios (Modelo Umbrella)

- **Raíz = repo de especificaciones.** Contiene las specs, las configuraciones globales y el issue de cada Historia de Usuario. Desde aquí se ejecutan los comandos de Spec Kit.
- **`/vault`**: repo propio por proyecto, submódulo de la raíz. Es la memoria del proyecto (lógica de negocio e información relevante). No guarda especificaciones ni `graphify-out/`. Rama única `main`, con `status: draft/approved` en el frontmatter para no romper enlaces.
- **`/backend`, `/frontend`, `/mobile`** (y los que defina el proyecto): código con Git Flow (`main`, `develop`, `feature/*`, `release/*`, `hotfix/*`). Cada uno tiene su `graphify-out/`. El stack lo define cada proyecto.

## 2. Ecosistema

- **Spec Kit (SDD):** las especificaciones viven en la raíz. Las ramas de especificación (`usr-*`, `rfr-*`, `hfr-*`) y del plan (`pl-*`) se crean **exclusivamente en el repositorio raíz**. En los submódulos de código **NO** se crean ramas durante specify ni plan; permanecen en su rama base (`develop`, `release` o `main`). Las ramas de trabajo en los submódulos nacen directamente de su rama base únicamente durante la implementación (`implement`) para cada tarea `TK`.
- **Extensión GitHub en Spec Kit:** `default_grouping: "user-story"`. Si la extensión no crea la jerarquía de issues enlazados, el agente la crea mediante el MCP de GitHub (a través de `issue-manager`).
- **Antigravity:** consume la checklist del issue Task en su rama, implementa de forma asíncrona, ejecuta pruebas de regresión y actualiza el ticket.
- **Graphify (`graphifyy`, con dos "y"; nunca `graphify-cli`):** genera el grafo del código de cada submódulo de código.
- **Git y GitHub solo mediante subagentes:** el agente principal no ejecuta `git`, `gh` ni el MCP de GitHub. Cada responsabilidad tiene su subagente:

| Subagente | Responsabilidad |
|---|---|
| `git-reader` | Toda LECTURA de git y GitHub: estado de repos y ramas, divergencias, trabajo en curso, diffs (exportados a archivo), issues, PR, tags, checks y campos del proyecto. |
| `git-operator` | Escritura en repositorios: ramas (y su vínculo con el issue), checkout, fast-forward, commit, push, punteros y alta de submódulos. |
| `issue-manager` | Issues: crear (`SP`, `PL`, `TK`), actualizar, comentar, marcar casillas, mover el estado en el proyecto y, solo para un `TK` en `Done`, cerrarlo (única forma de cierre de la metodología, exclusiva de `review-pr`). |
| `pr-manager` | Pull requests: crear sin palabras de cierre, publicar la revisión (aprobar, comentar o solicitar cambios) y fusionar solo con merge commit. |
| `release-manager` | Versionado `vMM.mm.pp`, release notes, tags y releases. |
| `github-setup` | Configuración del proyecto (estados, `Estimate`, iteración), etiquetas base y repositorio del Vault. |

  **Configuración SDD** (`CLAUDE.md`, `.agents/AGENTS.md`, configuración de Spec Kit, constitution, `.gitmodules`, puntero del Vault, `graphify-out/` inicial): no tiene rama propia. Se commitea, en un commit aparte, en la rama de trabajo activa del repo (especificación, plan o tarea) y llega a la base con su PR. Si se genera estando en una rama base, queda pendiente y la sube la siguiente rama de trabajo de ese repo. El Vault es la excepción: siempre `main`.

  Toda escritura requiere confirmación del usuario. **Optimización por lotes (Batching) en todos los subagentes:** para evitar consumos excesivos de tokens y demoras por llamadas repetitivas, las operaciones de un mismo paso se agrupan en una sola invocación por subagente: `git-reader` consolida todas las lecturas de verificación previas y finales; `git-operator` encadena checkouts, commits y pushes en una sola ejecución; `context-scout` extrae el contexto unificado de Vault y grafos en una sola llamada; y `issue-manager` procesa la creación de tickets en lote, actualización de estados y comentarios agrupados. Los subagentes que leen el Vault, los grafos o el código (`context-scout`, `legacy-analyzer`, `code-reviewer`, `vault-updater`, `poker-estimator`) no usan git; cuando necesitan un diff, lo reciben exportado a archivo por `git-reader`. Excepción declarada: los comandos de Spec Kit pueden crear o cambiar ramas por el preset; los verifica `git-reader`.

## 3. Roles

| Rol | Responsabilidad |
|---|---|
| **Arquitecto** | `specify`, `clarify`, `plan`, `analyze`, `tasks` y `taskstoissues`. Aprueba el Vault al crear las tareas. |
| **Desarrollador / Antigravity** | `implement` y ajustes técnicos. Actualiza el Vault con lo importante que surja de la implementación. |
| **PO** | Decide si un issue amarillo pendiente puede pasar a `main`. |

## 4. Issues, Prioridades e Impact Score

- **Issue de tipo User Story (fase `PL`):** vive en la raíz (repo de especificaciones) y representa una Historia de Usuario individual de la spec. Contiene la especificación completa de la US (narrativa, criterios de aceptación/escenarios, casos de borde, requerimientos, contratos y permisos) y agrupa las tareas `TK` de esa historia, que pueden ser transversales a varios repositorios.
- **Issues hijos de tipo Task (fase `TK`):** uno por Historia de Usuario y repositorio, cada uno con sus `T00X` como checklist.
- **Creación:** `taskstoissues` agrupa por US. Los issues de la metodología (`SP`, `PL`, `TK`) los crea y mantiene `issue-manager`.
- **Escala Oficial de Prioridades (4 niveles en GitHub Project y etiquetas):**
  - **`P0` (Crítico / Bloqueante / Rojo):** interrumpe procesos esenciales o es un cimiento bloqueante.
  - **`P1` (Alta / Requisito de Negocio / Amarillo):** funcionalidad central del sprint o extensión de dominio.
  - **`P2` (Media / Mejora Operativa / Verde):** optimizaciones, fallbacks, persistencias auxiliares y filtros secundarios.
  - **`P3` (Baja / Cosmético / Visual):** ergonomía visual, temas claro/oscuro, créditos, estilos CSS y microinteracciones de interfaz sin impacto operativo.
- **Regla Inviolable de Precedencia (Transitividad de Prioridades):**
  - Ningún issue de mayor prioridad puede depender ni estar bloqueado por un issue de menor prioridad: $\text{Priority}(B) \ge \text{Priority}(A)$ si $A$ depende de $B$.
  - Un issue `P0` no puede tener como prerrequisito un issue `P1`, `P2` o `P3`. Todo prerrequisito de un issue crítico hereda automáticamente la condición de `P0`.
- **Fórmula Recursiva de `Impact Score` (Grafo Ponderado Bottom-Up):**
  - Para ordenar la secuencia de ejecución dentro de una misma prioridad en GitHub Projects (`Sort: Priority ASC, Impact Score DESC`), cada issue calcula su puntuación de desbloqueo sumando el peso de los issues que bloquea más el score recursivo de estos:
    $$\text{ImpactScore}(u) = \sum_{v \in \text{Bloquea}(u)} \Big( W_{\text{base}}(v) + \text{ImpactScore}(v) \Big)$$
    con pesos base: $W_{\text{base}}(\text{P0}) = 4$, $W_{\text{base}}(\text{P1}) = 3$, $W_{\text{base}}(\text{P2}) = 2$, $W_{\text{base}}(\text{P3}) = 1$.
  - Las hojas terminales (que no bloquean a nadie) tienen $\text{ImpactScore} = 0$.
  - Ante cualquier cambio de prioridad o dependencia en un issue, el `Impact Score` se propaga reactivamente hacia todos sus ancestros en el DAG.
- **Validación Preventiva en la Creación de Issues (`SP` y `TK`):**
  - Al crear un `SP` o `TK`, se audita qué issues abiertos del mismo tipo lo bloquean. Si el nuevo issue es de mayor prioridad que sus bloqueantes, se ajusta la prioridad de los bloqueantes por transitividad y se recalculan los `Impact Score` de la cadena ascendente.
- **Grafo Central de Precedencia (`specs/DEPENDENCY_GRAPH.md`):**
  - El repositorio paraguas mantiene en la raíz un artefacto central con el diagrama Mermaid y la tabla consolidada de dependencias e `Impact Score` de todo el proyecto.

## 5. Conocimiento: Vault y Graphify

- **Vault:** el qué y el porqué (negocio). **`graphify-out/`:** el cómo está construido (código).
- **`graphify-out/`** contiene `graph.json`, `GRAPH_REPORT.md`, `graph.html` (D3 Force-Graph, modo oscuro, fondo `#0b0f19`) y `manifest.json`.
- **Protocolo del agente:**
  1. Lee `/vault` para entender la lógica de negocio.
  2. Decide a qué submódulo corresponde la responsabilidad.
  3. Lee el `graphify-out/` de ese submódulo.
- **Estados del Vault:**
  - Lo ya existente en proyectos legacy nace `approved`.
  - Lo que se escribe en `specify` nace `draft`.
  - Pasa a `approved` cuando se crean las tareas.
  - Lo que se actualiza durante la implementación pasa directo a `approved`.
- **`graphify-out/`:** sigue la rama activa (`feature/*`, `release/*` o `hotfix/*`) y es congruente con su código. Se regenera tras cada merge o rebase y nunca se fusiona a mano. En proyectos nuevos se genera la primera vez que haya código (por ejemplo, al primer merge a `develop`), con la instrucción en `CLAUDE.md` o `AGENTS.md`.

## 6. Flujo del sprint

1. **Diseño (Sprint N-1), a cargo del Arquitecto:**
   - `/speckit.specify --name <rama>` desde la raíz crea la rama de especificación únicamente en la raíz. Los submódulos no se tocan (como máximo se colocan en su rama base para lectura de grafos/código). El Vault se actualiza en `draft`.
   - `clarify`, `plan`, `analyze`, `tasks` y `taskstoissues`.
   - Al crear las tareas, las notas del Vault pasan a `approved`.
2. **Desarrollo (Sprint N):** `implement` crea en el submódulo la rama de tarea (`<spec>-<tk-xxx>`) **directamente desde la rama base del submódulo** (`develop`, `release` o `main`). Se actualiza el Vault con lo que surja de la implementación. Al terminar (`implement-close`), cada `TK` crea su PR **directamente hacia su rama base** en el submódulo, y pasa a `Implementado`.
3. **Revisión del PR:** `review-pr` relanza `code-reviewer` sobre el diff actual del PR, el usuario decide qué hallazgos publicar, descartar o reclasificar, y se publica la revisión en GitHub (`pr-manager`, `revisar`). Sin hallazgos publicados, el `TK` pasa a `Done` y se cierra (único cierre automático de un issue en toda la metodología); con hallazgos publicados, pasa a `Con Observaciones` y el retrabajo vuelve por `implement` → `implement-close` (mismo PR) → `review-pr`, hasta quedar aprobado.
4. **Sincronización:** tras cada PR aprobado y merge a `develop`, las demás ramas nacidas de `develop` se actualizan con **rebase**, y su `graphify-out/` se regenera. El historial se reescribe también en el repo remoto (`--force-with-lease`). Esta sincronización la hace el Desarrollador (o CI); ningún subagente de la metodología reescribe historial.
5. **Cierre de sprint:** pase a `release/*` con **tag nuevo** y **release notes**.
6. **Observaciones y correcciones:**
   - Van por release y pasan siempre por el Vault y Graphify según la responsabilidad.
   - Según su tamaño pasan o no por Spec Kit.
   - Cada observación genera un issue con la prioridad de su color.
   - Cada issue indica si el error es sobre `main` o sobre `release`, y en qué tag se identificó.
   - Los issues pasan automáticamente a la siguiente iteración.
7. **Paso a `main`:** cada sprint, según la semaforización.

## 7. Semaforización

| Color | Criterio | ¿Bloquea el paso a `main`? |
|---|---|---|
| 🔴 Rojo | Restringe procesos o rompe la funcionalidad a implementar | Sí |
| 🟡 Amarillo | No restringe procesos, pero incumple un requisito específico | Sí, **salvo aprobación del PO**, por sprint y por issue |
| 🟢 Verde | Errores leves | No |

- Al cerrar, el agente recomienda color y prioridad, y el usuario confirma o corrige.
- La aprobación del PO se registra en el propio issue amarillo.

## 8. Hotfix (error en producción)

El semáforo se aplica al detectar el error.

- 🔴 **Rojo:** se atiende con prioridad en el sprint actual. Si hace falta, se saca un release a `main` lo antes posible, con tag nuevo y release notes.
- 🟡/🟢 **Amarillo o verde:** va al backlog y espera al final del sprint.
- **Rama:** nace de `main`. Al cerrarse se hace merge a `main`, `develop` y `release`.
- **Trazabilidad:** pasa por el Vault y Graphify según la responsabilidad, y puede pasar o no por Spec Kit.

## 9. Prompt del Vault

El prompt del Vault (modos NUEVO y LEGACY) lo ejecuta la skill `init` en sus pasos 4 a 6; sus reglas están ahí.
