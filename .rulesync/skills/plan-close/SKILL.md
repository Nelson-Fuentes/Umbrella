---
name: plan-close
targets: ["*"]
description: "Cierra la fase de plan de la metodología SDD Umbrella (v8) como Arquitecto: verifica el plan, ejecuta /speckit.tasks y /speckit.analyze, resuelve las incongruencias con el usuario, hace commit, push y PR, crea un issue de tarea (TK) en cada submódulo por cada especificación e historia de usuario, con estimación de esfuerzo validada y prioridad, pasa las notas del Vault a approved y actualiza el estado de los issues PL y SP. Úsala al terminar plan y antes de implement."
---

# plan-close

> **Antigravity:** los subagentes se invocan con `invoke_subagent`; equivalencias de herramientas, `CLAUDE.md`/`AGENTS.md` y `/speckit.*` según la regla `sdd-antigravity-runtime` del plugin.

Es el cierre de la fase de plan. Verifica que el plan esté completo, genera las tareas, las revisa con `analyze`, sube todo en un PR y crea los issues de tarea. Cada acción que escribe en GitHub o en el Vault requiere confirmación del usuario. Esta skill NUNCA cierra issues: el `SP` sigue abierto hasta el final del proceso y los `PL` los cierra el usuario manualmente más adelante.

## Delegación
El contexto principal no ejecuta `git`, `gh` ni el MCP de GitHub:
- `git-reader`: rama activa, estados de los issues, `TK` abiertos del proyecto.
- `git-operator`: commits y push (rama del plan, Vault, puntero del Vault).
- `pr-manager`: PR del plan.
- `issue-manager`: issues `TK`, estados y comentario.
- `poker-estimator`: estimación (no usa git).

## Entradas (preguntar si faltan, nunca asumir)
- **Especificación:** su rama, o el número del issue `SP-xxx`.
- **Issues `PL` a cerrar:** por defecto, todos los de la especificación. El usuario puede indicar un subconjunto; los demás quedan pendientes para otro cierre. [CONFIRMAR]
- **El resto no se pregunta:** se lee del bloque "Metadatos SDD" de la spec (origen, issues `SP` y `PL`, rama de la especificación y rama del plan, submódulos, ruta del plan, stack y notas del Vault). Si falta algo, es un bloqueo: informarlo, no completarlo por suposición.

## Pasos (en orden)

### 1. Verificación del plan (en una sola llamada de lectura)
- `git-reader` en **UNA SOLA INVOCACIÓN** agrupada:
  - `estado-repos`: la raíz está en la rama del plan.
  - `rama`: la rama del plan está vinculada al `SP` y a los `PL`.
  - `issue`: los `PL` a cerrar están en `Backlog`, tienen el enlace al plan y a su sección, y el `SP` está en `Especificado` (o en `Planificando`, si ya hubo un cierre parcial de otros `PL`).
- En el contexto principal:
  - El plan existe y tiene una sección por historia de usuario, cada una con el proceso desde el punto de vista del usuario y del sistema (diagrama Mermaid con interacción entre capas de submódulos y flujo de datos, o listado ordenado), además de estructura de archivos y modelo de datos.
  - El stack de cada submódulo está fijado y la arquitectura respeta la del submódulo.
  - Las notas del Vault de la fase están en `draft`, son atómicas, y están en `01_Index/index.md` y `06_Logs/log.md`.
  - El bloque "Metadatos SDD" está al día.
- Si algo falta, informarlo como bloqueo y detenerse; no corregir en silencio.

### 2. Tareas
- Verificar con `specify --help` el comando exacto y ejecutar `/speckit.tasks` desde la raíz, en la rama del plan.
- Las tareas (`T00X`) deben quedar agrupadas por historia de usuario y cada una debe poder asignarse a un único submódulo (por su ruta o dominio). Si una tarea toca más de un submódulo, dividirla; si no pertenece a ninguno (p. ej. solo documentación o el Vault), reportarla y preguntar al usuario dónde va.
- **Estructura obligatoria por combinación (PL y submódulo):** Cada historia de usuario (`PL`) desglosará para cada submódulo involucrado sus tareas organizadas en 3 bloques obligatorios:
  1. **Setup:** Sincronización de rama base y preparación de la rama de trabajo del submódulo (directamente desde la rama base).
  2. **Implementación:** Tareas técnicas de dominio, puertos, casos de uso, persistencia, adaptadores y componentes.
  3. **Validación:** Compilación local del submódulo y ejecución de pruebas unitarias o de integración asociadas.
- El 100% de las tareas (`T001` a `T00N`) generadas en `tasks.md` debe quedar distribuido dentro de estos bloques sin dejar tareas huérfanas.

### 3. Analyze
- Ejecutar `/speckit.analyze` desde la raíz (verificar el comando exacto con `specify --help`). Es de solo lectura: revisa la consistencia entre la spec, el plan y las tareas.
- Registrar el resultado: cada incongruencia con su gravedad y dónde está.

### 4. Resolver las incongruencias
- Presentar al usuario las incongruencias de `analyze`. El agente propone la corrección y el usuario decide; el agente no decide por él.
- Corregir lo que corresponda en la spec, el plan o las tareas con las herramientas nativas (Edit y Write), siempre con confirmación del usuario antes de modificar la spec. Si un cambio afecta una nota del Vault, actualizarla con las reglas de la fase (atomizada, `draft`; la `approved` no se modifica).
- Volver a ejecutar `analyze` UNA sola vez tras las correcciones. Si aún quedan incongruencias bloqueantes, reportarlas como bloqueo para decidir con el usuario; no hacer más vueltas.
- Las incongruencias que el usuario decida aceptar sin corregir se registran de forma explícita en el bloque "Metadatos SDD".

### 5. Commit, push y PR
Con confirmación del usuario:
- `git-operator`:
  - en el Vault, `commit` + `push` de las notas `draft` directo a `main` (sin PR);
  - en la raíz, si hay configuración SDD pendiente (constitution actualizada, `CLAUDE.md`, etc.), primero un `commit` propio con ella (`chore(sdd): configuración SDD`) en la rama del plan;
  - después, en la raíz, `commit` + `push` a la rama del plan de todo lo producido (plan, tareas y correcciones), con `actualizar-puntero` del Vault (que apunta siempre a `main`).
  - En los submódulos no se commitea nada: su configuración SDD pendiente se sube en su rama de tarea.
- `pr-manager` (`crear`): PR desde la rama del plan hacia la rama base del origen (`develop`, `release` o `main`/`master`), la misma de la que nació; NO hacia la rama de la especificación. Pasando como `issues a vincular` los issues `SP` y `PL` para vincularlos en la sección Development (GraphQL `addCloseIssueReferences`) y en el proyecto. El cuerpo referencia los issues `SP` y `PL` SIN palabras de cierre automático.

### 6. Issues de tarea (TK)
Un issue por cada combinación de **historia de usuario (`PL`) y submódulo** (estrictamente **NUNCA** se crea un issue por cada tarea granular `T00X`).
- **Estructura interna obligatoria de cada issue `TK`:** El cuerpo de cada issue `TK` contendrá obligatoriamente la checklist de sus tareas `T00X` agrupada en:
  1. **Setup:** Sincronización de rama base y preparación de rama de tarea (directamente desde la rama base).
  2. **Implementación:** Tareas técnicas concretas en las capas correspondientes del submódulo.
  3. **Validación:** Compilación local y ejecución de pruebas unitarias/regresión.
- **Condición previa (no se salta):** no se crea ningún issue `TK` hasta que `analyze` se haya ejecutado (paso 3) y sus incongruencias estén resueltas o aceptadas de forma explícita por el usuario (paso 4). Si `analyze` no corrió, o quedan bloqueos sin decidir, detenerse e informarlo. Los issues se crean a partir de las tareas ya corregidas, no de las originales.
- **Plan de creación:** armar la tabla completa de issues a crear (historia de usuario/PL, submódulo, tareas `T00X` organizadas por Setup/Impl/Validación, estimación propuesta, prioridad propuesta y usuario asignado) y mostrarla al usuario para una única confirmación antes de crear nada. Con `git-reader` (`issues-proyecto`, fase `TK`) detectar los `TK` que ya existan para esta especificación (por un cierre anterior), para no duplicarlos.
- **Estimación de esfuerzo (Scrum Poker):** se estima en puntos de historia con la sucesión de Fibonacci (1, 2, 3, 5, 8, 13, 21), para el campo `Estimate` (número) del proyecto. Para cada issue a crear, lanzar 3 subagentes `poker-estimator` EN PARALELO, cada uno con una perspectiva distinta (desarrollo, arquitectura y revisión técnica, pruebas), pasándoles el issue (historia de usuario, submódulo, tareas `T00X`) y las rutas del plan, la spec y el `CLAUDE.md` del submódulo. [CONFIRMAR: las tres perspectivas.]
  - **Ronda 1:** votos independientes, sin ver los de los demás. Si los tres coinciden, ese es el valor (consenso).
  - **Ronda 2 (solo si no hay consenso):** pasar a cada subagente los votos y justificaciones de los tres, en especial los del voto menor y el mayor, y votar de nuevo. Una sola ronda extra.
  - **Valor recomendado:** el consenso o, si sigue sin haberlo, la mediana de los tres votos de la ronda 2. Si el valor es 21, o algún subagente recomienda dividir, recomendar dividir el issue (más tareas o más historias) en vez de crearlo tan grande. [CONFIRMAR: umbral para recomendar dividir.]
  - Con varios issues, lanzar los grupos de 3 en paralelo, por lotes.
  - Mostrar en la tabla de creación el valor recomendado y los votos de cada ronda. El usuario DEBE validarlo (confirmarlo o corregirlo); sin validación no se crea el issue.
- **Prioridad e Impact Score:** con `git-reader` (`issues-proyecto`, fase `TK`, abiertos), el agente la evalúa en relación con todos los `TK` abiertos del proyecto. Se verifica la **Regla de Transitividad** (si un `TK` depende de otro `TK` abierto del submódulo, el bloqueante no puede tener menor prioridad) y se calcula su `Impact Score` recursivo para el proyecto de GitHub. El usuario confirma o corrige.
- **Asignado:** preguntar al usuario a quién se asigna cada uno; nunca asumirlo.
- **Creación en lote:** `issue-manager` (`crear-lote`, fase `TK`), en **UNA SOLA INVOCACIÓN** para toda la lista de issues a crear. El subagente calcula el correlativo inicial una vez y genera todos los issues consecutivamente (`TK-001`, `TK-002`...):
  - se crea en el repositorio del submódulo correspondiente (no en la raíz), con la etiqueta `task`, y se vincula al proyecto de GitHub;
  - tiene el título `TK-001 [<TIPO>][<SIGLA SUBMÓDULO>] - <PL-XXX>: <título de la historia de usuario> (<Submódulo>)`, con el tipo heredado de la especificación;
  - indica en su descripción la especificación y la historia de usuario, el issue `PL` padre y la checklist de tareas `T00X` agrupada por Setup, Implementación y Validación;
  - queda como sub-issue del `PL` de su historia (jerarquía `SP` → `PL` → `TK`);
  - lleva la estimación validada y los campos `Priority` (`P0` a `P3`) e `Impact Score` asignados en ProjectV2, propagando los scores a los issues bloqueantes.
- Registrar los issues `TK` (número, enlace, historia de usuario y submódulo) en el bloque "Metadatos SDD" de la spec y, con confirmación, `git-operator` (`commit` + `push`) a la rama del plan, para que quede en el PR del paso 5.
- **Grafo Central de Precedencia:** Actualizar `specs/DEPENDENCY_GRAPH.md` en la raíz con el diagrama Mermaid de precedencia y las tablas actualizadas de `SP` y `TK`.

### 7. Vault a `approved`
Según la metodología, las notas `draft` de la especificación y del plan pasan a `approved` al crear las tareas. Con la confirmación del Arquitecto:
- Cambiar el `status` de CADA nota `draft` de esta especificación a `approved`, una por una (cada nota tiene su propio estado), incluidas las notas que describen un cambio planificado sobre una regla ya `approved`. Registrar el cambio en `01_Index/index.md` y `06_Logs/log.md`.
- `git-operator`: `commit` + `push` en la rama `main` del Vault, y `actualizar-puntero` del Vault en la rama del plan de la raíz.

### 8. Estados y comentario (agrupados en una sola llamada)
Acciones en los issues con confirmación del usuario. Se ejecutan agrupadas en **UNA SOLA INVOCACIÓN** a `issue-manager` (`lote-operaciones`):
- **Estados:**
  1. Cada `PL` cerrado en esta fase (ya con sus issues `TK` creados) pasa de `Backlog` a `Planificado`.
  2. Si es el primer `PL` de la especificación que llega a `Planificado`, el `SP` pasa a `Planificando`.
  3. Si con esto TODOS los `PL` de la especificación están en `Planificado`, el `SP` pasa a `Planificado`. Si quedan `PL` pendientes, el `SP` sigue en `Planificando` y se reportan los `PL` pendientes.
- **Comentario:** en el `SP`, resumen del cierre del plan con enlace al PR, issues `PL` y `TK` creados y resultado de `analyze`.
- **Verificación:** una sola comprobación posterior con `git-reader` (`issues-proyecto`) para verificar que los estados hayan cambiado en el proyecto.
- El issue `SP` NO se cierra, y tampoco los `PL`.

## Salida
Reporte corto con el resultado de cada paso y un veredicto:
- **LISTO PARA `implement`:** plan verificado, tareas generadas, `analyze` sin bloqueos, PR creado, issues `TK` creados con estimación validada, Vault en `approved`, los `PL` cerrados en `Planificado` y el `SP` en `Planificado` (o en `Planificando`, si quedan `PL` pendientes).
- **NO LISTO** (o parcial, si quedan `PL` pendientes): lista de bloqueos o pendientes, cada uno con qué falta, dónde y qué paso lo corrige.

Incluir: PR (número y enlace), cantidad de tareas, incongruencias encontradas y cómo se resolvieron o aceptaron, tabla de issues `TK` (enlace, historia de usuario, submódulo, estimación, prioridad, asignado) y dudas que necesitan decisión humana. La decisión final de pasar a `implement` es del usuario.
