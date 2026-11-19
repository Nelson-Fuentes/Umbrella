---
name: review-pr
targets: ["*"]
description: "Publica la revisión formal del PR de UN issue de tarea (TK) ya creado por implement-close en la metodología SDD Umbrella (v8): relanza code-reviewer sobre el diff actual del PR, presenta sus hallazgos al usuario para que decida en bloque cuáles publicar, descartar o reclasificar, publica el veredicto en GitHub (aprobar, comentar o solicitar cambios) y mueve el TK a Done con el issue cerrado, o a Con Observaciones si quedan hallazgos publicados. Se puede volver a invocar sobre el mismo PR tras corregir. Úsala después de implement-close."
---

# review-pr

> **Antigravity:** los subagentes se invocan con `invoke_subagent`; equivalencias de herramientas, `CLAUDE.md`/`AGENTS.md` y `/speckit.*` según la regla `sdd-antigravity-runtime` del plugin.

Es la compuerta de revisión formal del PR de UN `TK`, ya creado por `implement-close`. No implementa ni corrige nada: publica en GitHub el veredicto de `code-reviewer` sobre el estado actual del PR, según lo que el usuario decida publicar, y mueve el `TK` en consecuencia. Puede ejecutarse varias veces sobre el mismo PR, una por cada ronda de corrección.

## Delegación
El contexto principal no ejecuta `git`, `gh` ni el MCP de GitHub:
- `git-reader`: issue y estado del `TK`, PR vinculado, estado del submódulo, exportación del diff actual del PR.
- `code-reviewer`: revisión del diff exportado (subagente, contexto limpio, no usa git).
- `pr-manager`: publicación de la revisión en GitHub (`revisar`).
- `issue-manager`: estado del `TK` y, si corresponde, su cierre.

## Entradas (preguntar si faltan, nunca asumir)
- **Issue `TK`:** su número o enlace.
- **El resto no se pregunta:** PR vinculado, rama de trabajo, rama base, submódulo, issues `PL` y `SP`, ruta de la spec y del plan, constitution, `CLAUDE.md` del submódulo y notas del Vault de la fase se leen del `TK` (vía `git-reader`) y del bloque "Metadatos SDD" de la spec, igual que en `implement-close`. Si falta algo, es un bloqueo: informarlo, no completarlo por suposición.

## Pasos (en orden)

### 1. Verificación (en una sola llamada de lectura)
- `git-reader` en **UNA SOLA INVOCACIÓN** agrupada:
  - `issue` sobre el `TK`: está **abierto** y su `Status` es `Implementado` o `Con Observaciones`. Cualquier otro estado es un bloqueo: si está en `Implementando`, falta `implement-close`; si está en `Done`, ya se cerró y no se vuelve a revisar.
  - `pr`: existe, está **abierto** y vinculado al `TK`.
  - `estado-repos`: la rama del PR no tiene cambios sin commitear.
  - `diff`: exporta el diff `base...rama` del estado actual del PR a una ruta fuera del repositorio y devuelve la lista de archivos tocados.
- Si algo falla, detenerse e informar; no corregir en silencio. El camino de vuelta para corregir es `implement` + `implement-close`.

### 2. Marcar inicio de revisión
Con confirmación del usuario, `issue-manager` (`mover-estado`) lleva el `TK` a `En Revisión` (desde `Implementado` siempre; desde `Con Observaciones`, excepción fija de retroceso de la metodología).

### 3. Revisión de código
Lanzar `code-reviewer` (contexto limpio) con la ruta del diff exportado en el paso 1, la lista de archivos (indicando cuáles son configuración SDD, que no se revisan como parte del `TK`), el `TK` y las rutas del plan, la spec, la constitution, el `CLAUDE.md` del submódulo y las notas del Vault de la fase. Devuelve veredicto (`APROBADO` | `APROBADO CON OBSERVACIONES` | `CAMBIOS REQUERIDOS`) y hallazgos con severidad (`bloqueante`, `importante`, `menor`).

### 4. Triage con el usuario
Mostrar al usuario, de una sola vez, la lista completa de hallazgos (archivo y línea, severidad, origen de la regla y corrección sugerida) y el veredicto de `code-reviewer`. Pedirle que responda **en un solo bloque**:
- Qué hallazgos publicar tal cual.
- Qué hallazgos descartar (no se publican en GitHub; quedan solo en el reporte final de esta skill, como trazabilidad de lo que se pasó por alto).
- Qué hallazgos reclasificar, y a qué severidad final.

No continuar al paso 5 sin esta respuesta. No decidir por el usuario.

### 5. Publicación en GitHub
Con la selección del usuario, calcular la decisión:
- Sin ningún hallazgo publicado → `aprobar`.
- Con al menos un hallazgo publicado de severidad `bloqueante` (la final, tras reclasificar) → `solicitar-cambios`.
- Con hallazgos publicados pero ninguno `bloqueante` → `comentar`.

Con confirmación del usuario, `pr-manager` (`revisar`) publica la revisión con esa decisión. El cuerpo lista cada hallazgo publicado (archivo/línea, severidad final, corrección sugerida) y marca los reclasificados (p. ej. "reclasificado de `bloqueante` a `menor` por decisión del usuario"). Los hallazgos descartados NO aparecen en el cuerpo de GitHub.

### 6. Estado final del `TK`
Con el resultado del paso 5, en **UNA SOLA INVOCACIÓN** a `issue-manager` (`lote-operaciones`):
- **`aprobar` (sin hallazgos publicados):** `mover-estado` a `Done`, y después `cerrar` con un comentario de trazabilidad (enlace a la revisión publicada en el PR y el veredicto). Es la única forma en que la metodología cierra un `TK`.
- **`solicitar-cambios` o `comentar` (con hallazgos publicados):** `mover-estado` a `Con Observaciones` (avance normal desde `En Revisión`, no es un retroceso), y comentario en el `TK` con los hallazgos publicados y los descartados (para trazabilidad). El issue NO se cierra.
- **Verificación:** una sola comprobación posterior con `git-reader` (`issues-proyecto`) para validar que el estado quedó actualizado en el proyecto.

## Salida
Reporte corto con el resultado de cada bloque (verificación, revisión de `code-reviewer`, triage del usuario, publicación en GitHub, estado del `TK`) y un veredicto:
- **REVISIÓN PUBLICADA (APROBADO):** PR y revisión (enlace), `TK` en `Done` y cerrado.
- **REVISIÓN PUBLICADA (CON OBSERVACIONES):** PR y revisión (enlace), `TK` en `Con Observaciones`, hallazgos publicados y descartados, y que el camino de vuelta es `implement` (misma rama) → `implement-close` (reutiliza el PR existente) → `review-pr` de nuevo.
- **NO PUBLICADA:** lista de bloqueos, cada uno con qué falta y qué paso lo corrige.
