---
name: sdd-specify-close
description: "Cierra la fase de definición de la especificación (specify y clarify) en la metodología SDD Umbrella (v8): comprueba que la spec, el issue, el Vault y las ramas quedaron completos y consistentes, crea un issue de plan por cada historia de usuario de la spec, y emite un reporte de listo o no listo para pasar a plan. Úsala al terminar sdd-specify y antes de arrancar plan."
---

# sdd-specify-close

> **Antigravity:** los subagentes se invocan con `invoke_subagent`; equivalencias de herramientas, `CLAUDE.md`/`AGENTS.md` y `/speckit.*` según la regla `sdd-antigravity-runtime` del plugin.

Es la compuerta de salida de la fase de especificación. No rehace el análisis de `sdd-specify` (validación contra la constitution y el Vault); comprueba que todo lo que la fase debía dejar realmente quedó, y reporta si se puede pasar a `plan`. Verifica y reporta; no corrige en silencio.

## Delegación
El contexto principal no ejecuta `git`, `gh` ni el MCP de GitHub:
- `sdd-git-reader`: issue, ramas, cambios sin commitear, issues de plan del proyecto.
- `sdd-issue-manager`: issues de plan, comentario y estado del `SP`.
- `sdd-git-operator`: commit y push de la spec y del Vault, y puntero del Vault.
- `sdd-pr-manager`: PR de la especificación.

## Entradas (preguntar si faltan, nunca asumir)
- **Especificación a cerrar:** solo su rama, o el número del issue `SP-xxx`. En un lote de fixes, la lista de ítems; cada uno se verifica por separado y el reporte final es una tabla con una fila por ítem. [CONFIRMAR: cierre por ítem o todos juntos.]
- **El resto no se pregunta:** origen (USR, RFR o HFR), issue, rama base, submódulos, prioridad y notas del Vault se leen del bloque "Metadatos SDD" de la spec, que escribe `sdd-specify`. Si el bloque falta o está incompleto, es un bloqueo del cierre: informarlo, no completarlo por suposición. Comprobar además, con `sdd-git-reader` (`issue`), que el issue apunte de vuelta a la rama y a la ruta de la spec.

## Pasos (en orden)

### 1. Spec
- Existe la spec generada por `specify` (ruta de su reporte), en la rama confirmada de la raíz (rama activa según `sdd-git-reader`, `estado-repos`).
- Describe el qué y el porqué, sin stack tecnológico.
- No quedan ambigüedades sin resolver, salvo las que el usuario decidió dejar abiertas; esas deben figurar de forma explícita en la spec. [CONFIRMAR: si una ambigüedad abierta bloquea el cierre o basta con que el usuario la acepte.]
- Las decisiones de clarify están registradas en la spec.

### 2. Issue
Con `sdd-git-reader` (`issue`):
- Está abierto y en el formato `SP-001 [USR][SPC] - Nombre` (fase, correlativo, tipo, sigla de repositorio).
- Tiene la etiqueta `specification` y la de prioridad, usuario asignado, y está vinculado al proyecto de GitHub y a la rama de la raíz (Development).
- En fixes: color, prioridad, rama afectada (`main` o `release`) y tag.

### 3. Vault
- Cada regla o cambio que introduce la spec tiene su propia nota atómica, con su propio `status`; las nuevas, en `draft`.
- Cada nota nueva está en `01_Index/index.md` y registrada en `06_Logs/log.md`, enlaza con `[[...]]` a sus relacionadas e indica el submódulo responsable.
- Las notas que describen el cambio de una regla `approved` enlazan a ella; esta no fue modificada.
- No hay especificaciones ni `graphify-out/` dentro del Vault.
- NO se pasa ninguna nota a `approved`: eso ocurre al crear las tareas.

### 4. Ramas
Con `sdd-git-reader` (`rama` y `estado-repos`):
- La rama de la especificación existe en la raíz, con el nombre `usr-`, `rfr-` o `hfr-` acordado, nacida de la rama base correcta del origen (`develop`, `release` o `main`/`master`).
- En cada submódulo de código confirmado: NO existe rama de la especificación; cada submódulo se encuentra en su rama base correcta (`develop`, `release` o `main`/`master`) sin cambios no commiteados (salvo configuración SDD pendiente).
- Cambios sin commitear: en la raíz y el Vault se esperan (spec, notas `draft` y, en la raíz, configuración SDD pendiente de `sdd-init`; se suben en el paso 5). En los submódulos de código solo se acepta configuración SDD pendiente, que se informa y se sube en su rama de tarea; cualquier otro cambio es un bloqueo.

### 5. Acciones de cierre (cada una con confirmación del usuario)
- **Issues de plan (uno por historia de usuario):**
  - **Extracción completa por Historia de Usuario desde `spec.md`:**
    Para cada historia de usuario (`User Story X`) de la spec, extraer su bloque exhaustivo:
    1. Identificador y título de la historia (ej. `User Story 1 - Gobernanza por Unidad Logística...`).
    2. Narrativa completa: `Como <rol>, deseo <necesidad>, para <beneficio>`, `Why this priority` e `Independent Test`.
    3. Criterios de Aceptación / Escenarios de Aceptación (`Acceptance Scenarios` / CA) literales y completos con todos sus `Given ... When ... Then ...` o formato equivalente.
    4. Casos de Borde y Validaciones (`Edge Cases`): extraer las validaciones, casos límite y fallbacks de la spec que aplican a esa historia de usuario (o los casos de borde generales relevantes).
    5. Requerimientos, reglas y contratos técnicos: permisos asociados de la Matriz de Permisos, endpoints/servicios de contratos HTTP y notas de negocio del Vault vinculadas a la historia.
  - Mostrar al usuario la lista consolidada de historias de usuario a crear como issues `PL`, con su título, prioridad propuesta, asignado y resumen de alcance para su confirmación antes de crear nada.
  - `sdd-git-reader` (`issues-proyecto`, fase `PL`): issues de plan abiertos del proyecto, y los que ya existan para esta especificación (por un cierre anterior).
  - **Prioridad:** el agente la reevalúa para cada issue de plan, en relación con todos los `PL` abiertos del proyecto, no solo con los de esta especificación. Puede tomar como insumo la prioridad de la historia en la spec, pero no la hereda sin más. La propuesta se muestra en la misma lista de confirmación y el usuario confirma o corrige.
  - Preguntar al usuario a quién se asignan; nunca asumirlo.
  - **Creación en lote de issues `PL`:** Con confirmación del usuario, invocar a `sdd-issue-manager` (`crear-lote`, fase `PL`, etiqueta `plan`) en el repo raíz para crear todos los issues `PL` en **UNA SOLA INVOCACIÓN**. Se debe suministrar a `sdd-issue-manager` para cada historia TODO el contenido extraído (narrativa, criterios de aceptación, casos de borde, requerimientos, contratos y permisos). `sdd-issue-manager` calcula el correlativo base una vez y genera consecutivamente `PL-001 [<TIPO>][SPC] - <título de la historia>`, con el cuerpo completo y estructurado, asignando etiquetas, vinculación a ProjectV2 (`Priority`), y agregándolos como sub-issues del `SP`.
  - Registrar los issues de plan (número y enlace, con su historia) en el bloque "Metadatos SDD" de la spec, ANTES del commit.
- **Commit y push:** `sdd-git-operator`:
  - en el Vault, `commit` + `push` de las notas `draft` directo a `main` (sin PR);
  - en la raíz, si hay configuración SDD pendiente de `sdd-init`, primero un `commit` propio con ella (`chore(sdd-init): configuración SDD`) en la rama de la especificación;
  - después, en la raíz, `commit` + `push` de la spec en la rama de la especificación, junto con `actualizar-puntero` del Vault (que apunta siempre a `main`).
  - En los submódulos de código no se commitea nada en esta fase; la configuración SDD pendiente se sube en su rama de tarea.
- **PR:** `sdd-pr-manager` (`crear`) desde la rama de la especificación hacia su rama base (`develop`, `release` o `main`/`master`, según el origen), pasando como `issues a vincular` el issue `SP-xxx` para que quede formalmente conectado en su sección Development (vía GraphQL `addCloseIssueReferences`) y en el proyecto. El cuerpo referencia el issue SIN palabras de cierre automático, porque el issue no se cierra en esta fase. [CONFIRMAR: ¿se crea como borrador (draft), dado que la misma rama se usa luego para implementar?]

### 6. Estado del issue y comentario (agrupados en una sola llamada)
Acciones sobre el issue `SP` con confirmación del usuario. Se ejecutan agrupadas en **UNA SOLA INVOCACIÓN** a `sdd-issue-manager` (`lote-operaciones`):
1. **Estado del issue:** `mover-estado` a `Especificado` en el proyecto de GitHub.
2. **Comentario en el issue:** `comentar` con resumen de lo especificado y de las decisiones de clarify, enlace al PR y lista de issues de plan creados. El issue NO se cierra: permanece abierto hasta el final del proceso.
3. **Verificación:** inmediatamente tras la invocación a `sdd-issue-manager`, comprobar en una sola lectura con `sdd-git-reader` (`issue`) que el campo `Status` del issue en el proyecto figure efectivamente como `Especificado`. Si no cambió, es un bloqueo de cierre.

## Salida
Reporte corto con el resultado de cada bloque (spec, issue, Vault, ramas, issues de plan creados, PR y estado final verificado del issue en el proyecto) y un veredicto:
- **LISTO PARA `plan`:** todo cumple, incluyendo el PR creado, issues `PL` vinculados y el `SP` en estado `Especificado` verificado en el proyecto.
- **NO LISTO:** lista de bloqueos, cada uno con qué falta, dónde y qué fase o paso lo corrige (por ejemplo: estado no actualizado en el proyecto, PR pendiente o incongruencias en la spec).

La decisión final de pasar a `plan` es del usuario; el reporte solo la informa.
