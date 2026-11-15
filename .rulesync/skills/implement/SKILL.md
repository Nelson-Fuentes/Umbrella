---
name: implement
targets: ["*"]
description: "Ejecuta la fase de implementación de la metodología SDD Umbrella (v8) para UN issue de tarea (TK): comprueba que se puede implementar, crea la rama de trabajo en el submódulo directamente desde la rama base y la vincula al issue, mueve el TK a Implementando, lee el contexto (Vault y grafo), implementa las tareas T00X en orden, corre la regresión al terminar todas y pide una revisión de código. No hace commit ni push. Consulta siempre ante dudas. Úsala después de plan-close. No hace el PR ni cierra nada: eso lo hace implement-close."
---

# implement

> **Antigravity:** los subagentes se invocan con `invoke_subagent`; equivalencias de herramientas, `CLAUDE.md`/`AGENTS.md` y `/speckit.*` según la regla `sdd-antigravity-runtime` del plugin.

Cubre solo la implementación de UN issue `TK` en SU submódulo. El commit, el PR, el grafo, el Vault y los estados finales son de `implement-close`. Nunca cierra issues.

## Delegación
El contexto principal no ejecuta `git`, `gh` ni el MCP de GitHub:
- `git-reader`: issues, PR del plan, estado del submódulo, rama de trabajo y exportación del diff.
- `git-operator`: creación (o checkout) de la rama de trabajo vinculada al `TK`.
- `issue-manager`: estado del `TK`.
- `context-scout`: Vault y grafo.
- `code-reviewer`: revisión del diff exportado (no usa git).

## Cómo se invoca
El Desarrollador le indica a Antigravity que ejecute esta skill (`/implement`) y le entrega el issue `TK`. Se implementa un `TK` por corrida. El flujo es el mismo para USR, RFR y HFR; solo cambia la rama base, que sale del origen de la especificación.

## Entradas (preguntar si faltan, nunca asumir)
- **Issue `TK`:** su número o enlace (repositorio del submódulo).
- **El resto no se pregunta:** especificación (`SP`), issue `PL` padre, historia de usuario, submódulo, origen (USR, RFR o HFR), rama base, ruta de la spec y del plan (con la sección de la historia) y notas del Vault se leen del cuerpo del `TK` (vía `git-reader`, `issue`) y del bloque "Metadatos SDD" de la spec. Si falta algo, es un bloqueo: informarlo, no completarlo por suposición.

## Pasos (en orden)

### 1. Pre-chequeos (en una sola llamada de lectura)
Con `git-reader` en **UNA SOLA INVOCACIÓN** agrupada:
- `issue` sobre el `TK`, su `PL` y su `SP`: el `TK` está **abierto**, tiene la etiqueta `task` y su checklist `T00X` tiene tareas sin marcar; el `PL` y el `SP` están abiertos.
- `pr` del plan (rama del plan → rama base, en la raíz): **fusionado**. Si no lo está, es un bloqueo: la rama de trabajo nace de la base y necesita el plan.
- `estado-repos` sobre el submódulo y el Vault: **sin cambios sin commitear**, salvo configuración SDD pendiente en el submódulo (de `init` o del `CLAUDE.md` que actualizó `plan`), que pasa a la rama de trabajo al crearla y la commitea `implement-close`; y la rama base al día con su remota.
- `rama` con el nombre de la rama de trabajo: todavía **no existe**. Si ya existe y está vinculada a este `TK`, es una reanudación: informarlo, confirmar con el usuario y continuar en ella (paso 2b).

En el contexto principal: existe el `CLAUDE.md` del submódulo y la constitution.

Si algo falla, detenerse e informar; no corregir en silencio.

### 2. Rama de trabajo (primer paso de trabajo)
La crea esta skill directamente desde la rama base; no se espera que exista de antes.
- **Sin ramas intermedias:** en la metodología SDD Umbrella, `specify` y `plan` NO crean ramas en los submódulos. Por tanto, no existe ninguna rama previa de la especificación en el submódulo.
- **Nombre:** sugerir `<rama-de-la-especificacion>-<tk-001>` (p. ej. `usr-carga-masiva-clientes-tk-001`), en minúsculas y con guiones, y esperar la confirmación o corrección del usuario. [CONFIRMAR: formato del nombre.]
- **Crear, vincular y hacer checkout:** con confirmación, `git-operator` (`crear-rama`) en el submódulo, **directamente desde la rama base del origen** (`develop`, `release` o `main`/`master`, que actualiza por fast-forward antes de crear), vinculada al `TK` para que aparezca en su sección Development. Si la base no se puede actualizar por fast-forward, el operador lo reporta como bloqueo.
- **Comprobación:** `git-reader` (`rama`): la rama existe, nació de la base y está vinculada al `TK`.
- Trabajar SOLO sobre esa rama durante toda la fase.
- **2b. Reanudación:** `git-operator` (`checkout`) de la rama existente, que comprueba que esté al día con su remota; continuar desde la primera tarea sin marcar.

### 3. Contexto
- Lanzar `context-scout` con el `TK` y el propósito (implementar): lee del Vault y del grafo del submódulo (`GRAPH_REPORT.md` primero) solo lo necesario. El contexto principal no recorre el código a ciegas.
- Leer el `CLAUDE.md` del submódulo (arquitectura obligatoria y reglas), la sección del plan de la historia y la checklist `T00X` del `TK`.
- Las notas `approved` del Vault mandan; las `draft` relacionadas explican el cambio planificado.

### 4. Estado del `TK`
- Con confirmación, `issue-manager` (`mover-estado`) lleva el `TK` a `Implementando` (los estados de los `TK` son `Backlog` → `Implementando` → `Implementado`). Si el estado no existe en el proyecto, es un bloqueo de configuración (lo crea `github-setup`).
- Esta skill no mueve a `Implementado` ni cambia el estado de los padres (`PL`, `SP`): lo hace `implement-close`.

### 5. Implementar las tareas
Para cada tarea `T00X` sin marcar, en el orden de la checklist:
1. Implementar solo lo que pide la tarea y el plan, escribiendo el código con las herramientas nativas del editor (`write_to_file`, `replace_file_content`, `multi_replace_file_content`). Prohibido usar scripts secundarios para escribir o modificar código. Respetar la arquitectura del submódulo: en NUEVO, capas y dependencias (`domain` sin dependencias, `application` solo de `domain`, `infrastructure` implementa los puertos) y slice por módulo, sin acceder a las entrañas de otro módulo; en LEGACY, la arquitectura y el estilo detectados.
2. Escribir o actualizar las pruebas de la tarea.

Las casillas de la checklist del `TK` NO se marcan aquí: las marca `implement-close`. No se hace commit en esta skill: el commit, uno solo con todas las tareas del issue, lo hace `implement-close`.

**Pruebas de regresión:** al terminar TODAS las tareas del `TK`, correr la regresión completa del submódulo. Si fallan: corregir si la causa es de las tareas implementadas; si no, detenerse y consultar.

**Siempre consultar, nunca decidir por el usuario.** Ante cualquier duda o conflicto, detenerse y preguntarle al usuario, y no avanzar hasta recibir su respuesta. En particular cuando:
- El plan o la spec son ambiguos, se contradicen o no son implementables tal como están.
- La tarea exige tocar algo fuera del submódulo o fuera del alcance del `TK`.
- Una regla `approved` del Vault choca con lo que pide la tarea.
- Hay un conflicto o una regresión que no es de las tareas.
- El cambio exige otro lenguaje, framework o librería principal (desviación del plan).

Prohibido: ampliar el alcance, refactorizar fuera de lo pedido, cambiar el stack y saltarse pruebas.

### 6. Revisión de código
Con todas las tareas implementadas y la regresión en verde:
1. `git-reader` (`diff`) exporta el diff `base...rama` del submódulo, incluidos los cambios sin commitear, a una ruta fuera del repositorio (p. ej. `.sdd-tmp/<tk>.diff` en la raíz, ignorada por git), y devuelve la lista de archivos tocados.
2. Lanzar `code-reviewer` (contexto limpio) con la ruta del diff, la lista de archivos (indicando cuáles son configuración SDD, que no se revisan como parte del `TK`), el `TK` y las rutas del plan, la spec, la constitution, el `CLAUDE.md` del submódulo y las notas del Vault de la fase.
- Si devuelve hallazgos, listarlos al usuario con su origen y corregirlos con su confirmación; después volver a correr la regresión.
- No se lanza una segunda revisión completa salvo que el usuario lo pida.

### 7. Validación
Esta skill NO hace commit ni push. Antes de terminar, comprobar:
- Todas las tareas `T00X` del `TK` están implementadas (según la revisión: ninguna "tarea sin evidencia en el diff").
- La regresión pasa.
- La lista de archivos tocados (de `git-reader`) no contiene nada fuera del alcance del `TK`, aparte de la configuración SDD pendiente.
- Los cambios quedan en el árbol de trabajo de la rama, sin commitear.

## Salida
Reporte corto: rama creada y a qué issue quedó vinculada, tareas implementadas, resultado de la regresión, hallazgos de la revisión y su resolución, y dudas que necesitan decisión humana. Indicar que quedan cambios sin commitear en la rama de trabajo, y que el commit, el push, el PR (uno por submódulo), la regeneración del grafo, el Vault y el paso del `TK` a `Implementado` (y los estados de sus padres) quedan a cargo de `implement-close`.
