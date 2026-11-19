---
name: implement-close
targets: ["*"]
description: "Cierra la implementación de UN issue de tarea (TK) en la metodología SDD Umbrella (v8): verifica el trabajo hecho por implement, hace el commit único y el push, regenera el grafo del submódulo, actualiza el Vault a approved con vault-updater, marca las casillas del TK, crea el PR de la rama de trabajo hacia la base del submódulo (o agrega commits de corrección al PR existente si el TK viene de Con Observaciones) y actualiza los estados del TK, su PL y su SP. Nunca cierra issues. Úsala al terminar implement, y de nuevo tras corregir las observaciones de review-pr."
---

# implement-close

> **Antigravity:** los subagentes se invocan con `invoke_subagent`; equivalencias de herramientas, `CLAUDE.md`/`AGENTS.md` y `/speckit.*` según la regla `sdd-antigravity-runtime` del plugin.

Es la compuerta de salida de la implementación de UN `TK`. Verifica, deja el conocimiento (grafo y Vault) al día, crea el PR y mueve los estados. Cada acción que escribe en GitHub, en un repositorio o en el Vault requiere confirmación del usuario. NUNCA cierra issues (`TK`, `PL` ni `SP`).

## Delegación
El contexto principal no ejecuta `git`, `gh` ni el MCP de GitHub:
- `git-reader`: issues y estados, rama y estado del submódulo, exportación del diff, comprobación del PR.
- `git-operator`: commits y push (código, grafo, Vault, puntero del Vault).
- `pr-manager`: PR del `TK`.
- `issue-manager`: casillas, comentario y estados.
- `vault-updater`: propuesta de cambios en el Vault a partir del diff exportado (no usa git).

## Entradas (preguntar si faltan, nunca asumir)
- **Issue `TK`:** su número o enlace.
- **El resto no se pregunta:** rama de trabajo (la vinculada al `TK`), rama base, submódulo, issues `PL` y `SP`, ruta de la spec y del plan y notas del Vault se leen del `TK` (vía `git-reader`) y del bloque "Metadatos SDD" de la spec. Si falta algo, es un bloqueo: informarlo, no completarlo por suposición.

## Pasos (en orden)

### 1. Verificación (en una sola llamada de lectura)
- `git-reader` en **UNA SOLA INVOCACIÓN** agrupada:
  - `issue` sobre el `TK`, el `PL` y el `SP`: el `TK` está abierto y en `Implementando` (primera vez) o en `Con Observaciones` (retrabajo tras una revisión con hallazgos; ver "PR de la tarea" más abajo); su `PL` y su `SP` están abiertos.
  - `rama` y `estado-repos`: la rama de trabajo existe, está vinculada al `TK` y es la rama activa del submódulo; tiene cambios sin commitear (los de `implement`) y no hay otros cambios sin commitear en el Vault.
  - `pr`: si el `TK` viene de `Con Observaciones`, ya existe un PR abierto de esa rama hacia la base; se reutiliza (ver paso 5), no se crea otro.
  - `diff`: exporta el diff `base...rama` (con los cambios sin commitear) a una ruta fuera del repositorio y devuelve la lista de archivos tocados.
- Cada tarea `T00X` tiene su implementación en los cambios y estos no contienen nada fuera del alcance del `TK` (la configuración SDD pendiente se separa y no cuenta como fuera de alcance): se comprueba con la lista de archivos tocados y con la revisión de `code-reviewer` (sin "tareas sin evidencia en el diff"). Si falta una tarea o sobra código, es un bloqueo: informarlo, no corregirlo aquí.
- La regresión del submódulo pasa (correrla de nuevo en esta rama).
- La revisión de `code-reviewer` se hizo y sus hallazgos están resueltos o aceptados por el usuario.
- Si algo falla, detenerse e informar; no corregir en silencio. El camino de vuelta es `implement`.

### 2. Commit, grafo y push (en una sola invocación a git-operator)
- Regenerar `graphify-out/` del submódulo con `graphify` (paquete `graphifyy`) para reflejar los cambios terminados.
- Con confirmación del usuario, `git-operator` ejecuta en **UNA SOLA INVOCACIÓN** encadenada en el submódulo:
  1. Si hay configuración SDD pendiente (`CLAUDE.md`, `.agents/AGENTS.md`), commit propio con ella (`chore(sdd): configuración SDD`).
  2. Commit de todas las tareas del `TK` (mensaje: `TK-001: <título de la historia>`, cuerpo con checklist de tareas `T00X`).
  3. Commit de actualización del grafo (`graphify-out/`).
  4. `push` de la rama de trabajo a su remota.

### 4. Vault
- Lanzar `vault-updater` con la ruta del diff exportado en el paso 1, la lista de archivos tocados, el `TK` y las notas del Vault de la fase (metadatos de la spec): compara lo implementado con las notas y devuelve cuáles cambian y cuáles faltan.
- Mostrar al usuario cada cambio propuesto y esperar su confirmación. Después aplicar con las herramientas nativas del editor (`write_to_file`, `replace_file_content`); prohibido usar scripts secundarios para escribir notas.
- Reglas: notas atómicas, cada una con su propio `status`. Las notas `approved` que cambia la implementación se actualizan en el momento y quedan en `approved`; las notas nuevas que surjan de la implementación se crean directo en `approved`, con enlaces `[[...]]` a sus relacionadas y el submódulo responsable. La nota de cambio planificado que creó el plan se deja enlazada como historial. [CONFIRMAR: qué hacer con ella una vez aplicado el cambio.]
- Registrar cada nota nueva en `01_Index/index.md` y cada cambio en `06_Logs/log.md` (append-only).
- NO guardar la spec, el plan ni `graphify-out/` en el Vault.
- Con confirmación, `git-operator` (`commit` + `push`) directo a la rama `main` del Vault (sin PR). El puntero del submódulo del Vault en la raíz apunta siempre a `main`; actualizarlo con `actualizar-puntero` si cambió. [CONFIRMAR: en qué rama de la raíz se sube ese puntero, si la raíz no tiene rama de trabajo en esta fase.]

### 5. PR de la tarea
Con confirmación del usuario:
- **Primera vez (el `TK` venía de `Implementando`):** `pr-manager` (`crear`) en el repositorio del submódulo, **directamente desde la rama de trabajo hacia la rama base del submódulo** (`develop`, `release` o `main`/`master`, según el origen del `SP`), NUNCA hacia una rama de especificación intermedia (que no existe en los submódulos). Pasando como `issues a vincular` el `TK` (y referencias a `PL` y `SP`) para vincularlos en su sección Development (vía GraphQL `addCloseIssueReferences`) y en el proyecto. Es un PR por submódulo, uno por `TK`.
  - Título: `TK-001 [USR][BCK] - <título de la historia>` (el del issue).
  - Cuerpo: referencia al `TK`, al `PL` y al `SP` (con enlaces) SIN palabras de cierre automático, resumen de lo implementado por tarea, resultado de la regresión, resultado de la revisión y notas del Vault actualizadas.
  - Vinculado al `TK` (sección Development). Comprobarlo con `git-reader` (`issue`).
- **Retrabajo (el `TK` venía de `Con Observaciones`):** NO se crea un PR nuevo. El PR detectado en el paso 1 ya existe y ya tiene los commits del paso 2 (mismo push de la rama). Solo se actualiza su cuerpo, agregando una entrada fechada con el resumen de lo corregido y el resultado de la nueva regresión; el camino para republicar la revisión en GitHub es `review-pr`, no esta skill.

### 6. Casillas, estados y comentario (agrupados en una sola llamada)
Con el PR creado y confirmación del usuario, ejecutar en **UNA SOLA INVOCACIÓN** a `issue-manager` (`lote-operaciones`) todas las acciones sobre los issues:
1. **Marcar casillas:** marcar todas las casillas `T00X` del `TK`.
2. **Mover estados (en el proyecto de GitHub):**
   - **`TK`:** a `Implementado` (desde `Implementando` la primera vez; desde `Con Observaciones` en un retrabajo, retroceso permitido por excepción fija de `issue-manager`).
   - **`PL` de la historia:** a `Implementando` cuando al menos uno de sus `TK` está en `Implementado` o más avanzado (`En Revisión`, `Con Observaciones` o `Done`); a `Implementado` cuando todos sus `TK` lo están.
   - **`SP`:** a `Implementando` cuando al menos un `PL` está en `Implementando` o `Implementado`; a `Implementado` cuando todos sus `PL` están en `Implementado` (solo cuando todos sus `PL` ya están en `Planificado` o más avanzado).
3. **Comentario en el `TK`:** enlace al PR, resumen de lo hecho y de las decisiones consultadas durante la implementación. El issue NO se cierra.
4. **Verificación:** una sola comprobación posterior con `git-reader` (`issues-proyecto`) para validar que los estados quedaron actualizados en el proyecto.

## Salida
Reporte corto con el resultado de cada bloque (verificación, commit y push, grafo, Vault, casillas, PR, estados) y un veredicto:
- **IMPLEMENTADO:** todo cumple. Indicar PR (número y enlace), estado final del `TK`, del `PL` y del `SP`, y cuántos `TK` quedan pendientes en el `PL`.
- **NO CERRADO:** lista de bloqueos, cada uno con qué falta, dónde y qué paso lo corrige.

Quedan fuera de esta skill, por ser automatizables o manuales: regenerar `graphify-out/` tras cada merge o rebase, sincronizar las demás ramas con la base tras un merge, y cerrar los issues `PL` y `SP`. La revisión formal del PR en GitHub (aprobar, comentar o solicitar cambios) y el cierre del `TK` son de `review-pr`, que se invoca después de esta skill.
