---
name: specify
targets: ["*"]
description: "Ejecuta la fase specify de la metodología SDD Umbrella (v8) como Arquitecto, para un nuevo requerimiento, un fix de release o un hotfix (varios fixes en un solo prompt): valida que lo pedido no esté ya implementado ni en curso en otra línea, semaforiza los fixes y prioriza los requerimientos, sugiere rama y submódulos, crea el issue en GitHub, ejecuta /speckit.specify y /speckit.clarify desde la raíz, deja en draft lo nuevo en el Vault y valida la spec contra la constitution y el Vault. Úsala al arrancar el diseño de una Historia de Usuario o de una corrección."
---

# specify

> **Antigravity:** los subagentes se invocan con `invoke_subagent`; equivalencias de herramientas, `CLAUDE.md`/`AGENTS.md` y `/speckit.*` según la regla `sdd-antigravity-runtime` del plugin.

Cubre `specify` y `clarify`. `plan`, `analyze`, `tasks` y `taskstoissues` son otras fases.

## Delegación
El contexto principal no lee código ni ejecuta `git`, `gh` ni el MCP de GitHub:
- `context-scout`: Vault y grafos.
- `git-reader`: estado de repos y ramas, trabajo en curso, issues del proyecto.
- `git-operator`: creación de la rama de la raíz vinculada al issue.
- `issue-manager`: creación y actualización del issue `SP`.

**Excepción declarada:** los comandos de Spec Kit (`/speckit.specify` con el preset multi-repo) pueden crear o cambiar ramas por sí mismos. Los ejecuta el contexto principal porque son Spec Kit, no gestión de git; toda comprobación posterior la hace `git-reader`.

## Entradas (preguntar si faltan, nunca asumir)

- **Origen:** nuevo requerimiento | fix de release | hotfix.
- **Descripción:** texto libre, o un issue / archivo del que partir (ruta, número o enlace). Puede venir en cualquiera de las dos formas. Si es un issue, lo lee `git-reader` (`issue`).
- **Solo en fixes:** si el error es sobre `main`/`master` o sobre `release`, y en qué tag se identificó.
- **Varias especificaciones en un prompt:** válido SOLO para fixes (ver "Lote de fixes"). Un requerimiento se especifica de a uno: si el prompt trae varios requerimientos, o un requerimiento mezclado con fixes, pedir al usuario que los envíe por separado.

## Rama base según el origen

| Origen | Sigla | Rama base (repo raíz y submódulos) | Semaforización | Prioridad del issue |
|---|---|---|---|---|
| Nuevo requerimiento | USR (User Story Requirement) | `develop` | No | Relativa a los demás requerimientos del proyecto |
| Fix de release | RFR (Release Fix Requirement) | `release` | Sí | Hereda la de la semaforización |
| Hotfix | HFR (Hot Fix Requirement) | `main` o `master` (la que exista) | Sí | Hereda la de la semaforización |

## Nombre de la rama

Formato: `<sigla>-<nombre-de-la-especificacion>`, sigla en minúsculas y nombre en minúsculas con guiones. Ejemplos: `usr-carga-masiva-clientes`, `rfr-total-factura-redondeo`, `hfr-login-caido`. Esta rama se crea **ÚNICAMENTE en el repositorio raíz**. En los submódulos de código **NO** se crea ninguna rama durante specify; como máximo se hace checkout a su rama base (`develop`, `release` o `main`/`master`) para lectura de grafos y código.

## Metadatos de la spec (vínculo spec ⇄ issue)

La spec que crea Spec Kit lleva al inicio un bloque de metadatos, que esta skill crea y completa a lo largo de la fase. Es la fuente de las entradas de `specify-close` y de las fases siguientes: nadie vuelve a preguntar estos datos.

```markdown
## Metadatos SDD
- Origen: USR | RFR | HFR
- Issue: SP-001 [USR][SPC] - Nombre (#número, enlace)
- Rama: usr-nombre (rama base: develop | release | main/master)
- Submódulos afectados: ...
- Prioridad: ... (en fixes: color, rama afectada `main` o `release`, tag)
- Notas del Vault en draft: rutas
- Ambigüedades abiertas aceptadas por el usuario: ...
```

El vínculo es en ambos sentidos: la spec guarda el issue y el origen, y el issue guarda la rama y la ruta de la spec (se agrega con `issue-manager`, operación `actualizar`).

## Lote de fixes

Si el usuario pasa varios fixes en un solo prompt:
1. Separarlos en ítems y mostrar la lista al usuario para que confirme o corrija la separación.
2. Los pasos 2 a 7 se hacen para todos los ítems por adelantado y se presentan en UNA sola tabla (origen, color y prioridad recomendados, rama, submódulos, issue existente si lo hay) para una única confirmación.
3. Comprobar también que los ítems no sean duplicados entre sí.
4. Los pasos 8 a 11 se ejecutan ítem por ítem, en orden de prioridad (rojo primero). Cada fix tiene su propia spec, su propia rama y su propio issue; nunca se mezclan en una spec.
5. Cada ítem puede tener origen distinto (uno de release, otro hotfix).

## Pasos (en orden)

### 1. Pre-chequeos
- La raíz es el repo de especificaciones y `init` ya se ejecutó: existen `CLAUDE.md`, la constitution, el preset `spec-kit-preset-multi-repo-branching` y la extensión GitHub (comprobación de archivos y de `specify`, en el contexto principal).
- `git-reader` (`estado-repos`) sobre la raíz, los submódulos y el Vault: cada repo de código tiene rama de producción, `develop` y `release`, y no hay cambios sin commitear, salvo configuración SDD pendiente de `init`. Esa se permite: en la raíz pasa a la rama de la especificación al crearla (paso 8) y la commitea `specify-close`; en los submódulos queda pendiente hasta su rama de tarea. Cualquier otro cambio sin commitear es un bloqueo.
- Si algo falla (incluida la ausencia de la constitution), detenerse e informar; no corregir en silencio.

### 2. Origen
Confirmar con el usuario el origen y, en fixes, el tag y si el error es sobre `main` o sobre `release`. Fijar la rama base según la tabla.

### 3. Contexto mediante subagentes (en una sola llamada)
- Lanzar `context-scout` en **UNA SOLA INVOCACIÓN** con la descripción y el origen (si son varios fixes, enviar la lista completa en un único prompt). El subagente analiza el contexto consolidado de Vault y grafos sin lanzar scouts fragmentados. El contexto principal NO lee el código, ni el Vault completo, ni los grafos completos.
- Devuelve: reglas de negocio relevantes (con su `status`), submódulos responsables, componentes del grafo implicados, huecos, si lo pedido ya parece implementado y notas `draft` relacionadas.

### 4. Validación previa: ¿ya existe o ya se está haciendo?
**4a. ¿Ya está implementado?** (todos los orígenes)
- Con el resumen de `context-scout` (reglas `approved` y grafo), comprobar si lo pedido ya existe.
- Si ya está implementado: informar al usuario qué existe y dónde (nota del Vault y submódulo), y preguntarle cuál sería el diferencial que debe implementar la especificación. No continuar hasta tener esa respuesta; el diferencial pasa a ser el alcance de la spec.

**4b. ¿Ya se está implementando en otra línea?** (solo fixes)
- **Hotfix:** comprobar que no se esté corrigiendo en `release` ni en `develop`.
- **Fix de release:** comprobar que no se esté corrigiendo en `develop`.
- `git-reader` (`trabajo-en-curso`) en el repo raíz Y en cada submódulo de código, con la descripción del fix y las ramas de origen que correspondan: ramas nacidas de ellas (revisando commits y archivos tocados, no solo el nombre), PR abiertos e issues abiertos relacionados. Las notas `draft` del Vault salen de `context-scout` (paso 3).
- Si se está implementando: indicar al usuario el issue (número y enlace) y preguntarle si debe subirse la prioridad y si debe modificarse el issue (por ejemplo, ampliar su alcance o descripción). Con su confirmación, `issue-manager` (`actualizar`):
  - subir la prioridad del issue existente,
  - modificar el issue existente,
  - ambas cosas, en lugar de crear una spec duplicada,
  - o continuar con una spec nueva si el usuario lo decide.

### 5. Semaforización (fixes) y prioridad (requerimientos)
**Fixes: semaforización**
- Recomendar color y prioridad, con el criterio de la metodología:
  - 🔴 Rojo: restringe procesos o rompe la funcionalidad a implementar. Bloquea el paso a `main`.
  - 🟡 Amarillo: no restringe procesos pero incumple un requisito específico. Bloquea salvo aprobación del PO, por sprint y por issue.
  - 🟢 Verde: errores leves. No bloquea.
- Hotfix rojo: prioridad en el sprint actual, y release a `main` lo antes posible. Hotfix amarillo o verde: backlog hasta el final del sprint.
- El usuario confirma o corrige. El issue hereda esta prioridad.

**Nuevos requerimientos: prioridad relativa (escala oficial P0 a P3)**
- `git-reader` (`issues-proyecto`, fase `SP`, tipo USR, abiertos) devuelve los requerimientos abiertos. Recomendar una prioridad en la escala oficial de 4 niveles:
  - `P0`: crítico o cimiento bloqueante.
  - `P1`: requerimiento central de negocio.
  - `P2`: optimizaciones y mejoras secundarias.
  - `P3`: mejoras cosméticas, visuales y ergonomía.
- El usuario confirma o corrige.

### 6. Rama y submódulos
- Sugerir al usuario el nombre de la rama para la raíz (`usr-...`, `rfr-...` o `hfr-...`, según el origen) y listar qué submódulos son afectados con su rama base correspondiente (`develop`, `release` o `main`/`master`). Recordar que los submódulos NO recibirán ramas en esta fase.
- Esperar confirmación o corrección del usuario antes de ejecutar nada.

### 7. Issue en GitHub, Precedencia e Impact Score
Toda especificación genera un issue en el repo raíz (repo de especificaciones), con confirmación del usuario sobre su contenido antes de crearlo. Si el issue ya existía como entrada, reutilizarlo en vez de crear otro.
- **Validación Preventiva de Precedencia y Transitividad:**
  - Auditar qué issues `SP` abiertos bloquean o son prerrequisito del nuevo requerimiento.
  - Si el nuevo issue es `P0` y algún issue bloqueante es `P1`, `P2` o `P3`, se aplica la **Regla de Transitividad**: se eleva inmediatamente la prioridad del issue bloqueante a `P0` tanto en el repo como en el proyecto de GitHub.
  - Se calcula el `Impact Score` recursivo sumando el peso $(W_{\text{base}} + \text{ImpactScore})$ de abajo hacia arriba en el DAG y propagando a todos los issues ancestros abiertos.
- **Fix de release / hotfix:** hereda la prioridad (y el color) de la semaforización; indica si el error es sobre `main` o `release` y el tag en que se identificó.
- **Nuevo requerimiento:** issue de tipo requerimiento, con la descripción formal del requerimiento como descripción, etiquetado con la prioridad confirmada en el paso 5.
- Preguntar al usuario a quién se asigna el issue; nunca asumirlo.
- Tras la confirmación, `issue-manager` (`crear`, fase `SP`) con: tipo (`USR`, `RFR` o `HFR`), sigla del repositorio, nombre, descripción, prioridad (`P0` a `P3`), `Impact Score` calculado, usuario asignado, proyecto de GitHub y, en fixes, rama afectada y tag. Él calcula el correlativo, aplica el formato `SP-001 [USR][SPC] - Nombre`, asigna las etiquetas y campos `Priority` e `Impact Score` en el proyecto, y propaga el score hacia los ancestros.
- En un lote de fixes, los issues se crean en **UNA SOLA INVOCACIÓN** a `issue-manager` (`crear-lote`, fase `SP`), calculando el correlativo base una vez y generando consecutivamente todos los issues del lote en orden de prioridad.

### 8. Rama y specify
- Verificar con `specify --help` los comandos y flags exactos de la versión instalada.
- **Rama de la raíz vinculada al issue:** con confirmación del usuario, `git-operator` (`crear-rama`) crea en la raíz la rama acordada desde la rama base del origen, ya vinculada al issue del paso 7 (sección Development), con checkout. Si el issue es el de un fix o requerimiento preexistente, se vincula igual.
- **Submódulos de código (NO tocar ni crear ramas):** `specify` NO crea ramas en los submódulos. Si algún submódulo afectado no se encuentra en su rama base del origen (`develop`, `release` o `main`/`master`), `git-operator` (`checkout`) realiza checkout a esa rama base para asegurar que la lectura de grafos y código sea exacta y consistente.
- Desde la raíz, ejecutar `/speckit.specify --name <rama>` con la descripción (y, en fixes, la semaforización y el diferencial si lo hubo), referenciando el issue.
- **Comprobación:** `git-reader` (`rama` en la raíz e `issue`): la rama existe en la raíz, nació de la rama base correcta, la raíz quedó en ella y el issue la muestra en Development; y los submódulos afectados permanecen en su rama base limpia.
- **Metadatos y vínculo inverso:** escribir en la spec el bloque "Metadatos SDD" (origen, issue con número y enlace, rama y rama base, submódulos, prioridad y, en fixes, color, rama afectada y tag). Después, con confirmación, `issue-manager` (`actualizar`) agrega al issue la rama y la ruta de la spec.
- La spec describe el qué y el porqué, sin stack tecnológico. Las ambigüedades quedan marcadas para clarify, no se resuelven por suposición.

### 9. Vault en `draft`
- Escribir en el Vault solo lo que NO está aún en desarrollo: reglas, entidades, flujos o módulos nuevos que introduce la spec.
- Atomizar: cada regla de negocio, y cada modificación que acompañe a la especificación, va en su propia nota, con su propio `status` en el frontmatter. No agrupar varias reglas o cambios en una misma nota.
- Cada nota nueva lleva `status: draft`, enlaces `[[...]]` a las notas relacionadas e indica el submódulo responsable.
- Si la spec cambia una regla `approved`: crear una nota nueva en `draft` que describa el cambio planificado (qué regla cambia, de qué a qué y por qué) y enlace con `[[...]]` a la nota `approved`. La nota `approved` NO se modifica; se actualiza durante la implementación y pasa directo a `approved`.
- Registrar cada nota en `01_Index/index.md` (resumen de una línea) y el cambio en `06_Logs/log.md` (append-only), y agregar sus rutas al bloque "Metadatos SDD" de la spec.
- Atomización de notas existentes: si una nota `approved` agrupa varias reglas y la spec afecta solo a una, extraer esa regla a su propia nota atómica `approved` (mismo contenido, sin cambios de fondo) y dejar en la nota original el enlace `[[...]]` a ella, para que cada regla tenga su propio estado. Pedir confirmación al usuario antes de reestructurar una nota `approved`, y registrar el cambio en `01_Index/index.md` y `06_Logs/log.md`.
- Fuera de esa atomización, NO modificar notas `approved` ni notas de lo ya existente. NO guardar especificaciones ni `graphify-out/` en el Vault.
- Usar solo las herramientas nativas del editor (Write y Edit). Prohibido usar scripts secundarios para escribir notas.
- El commit y push de la spec y del Vault no se hacen aquí: los hace `specify-close`.

### 10. Clarify
- Verificar con `specify --help` el comando exacto y ejecutar `/speckit.clarify` desde la raíz sobre la spec.
- Hacer al usuario las preguntas de clarificación que resulten (una por vez) y registrar las respuestas en la spec. Las decisiones las toma el usuario; el agente no responde por él.
- Tras clarify, actualizar las notas `draft` del Vault que dependan de lo aclarado (mismas reglas del paso 9) y registrar el cambio en `06_Logs/log.md`.
- Las ambigüedades que el usuario decida dejar abiertas se reportan en la salida y se registran en el bloque "Metadatos SDD" de la spec.

### 11. Validación
Antes de terminar, comprobar la spec (ya clarificada) contra:
- **La constitution:** principios, arquitectura obligatoria por tipo de submódulo y reglas del Vault.
- **El Vault:** que no contradiga reglas `approved`, salvo los cambios ya registrados en una nota `draft` enlazada (paso 9), y que sea congruente con las `draft` que acaba de escribir.

Si hay inconsistencias, listarlas con su origen (qué parte de la spec choca con qué regla) y proponer la corrección. No modificar la spec ni el Vault sin confirmación del usuario.

## Salida
Reporte corto (en un lote de fixes, una fila por ítem): origen y rama base, resultado de las validaciones previas (ya implementado / en curso en otra línea), semaforización o prioridad, issue creado (número y enlace) y vinculado a la rama, rama creada en la raíz (submódulos en su rama base), spec generada (ruta), notas del Vault creadas en `draft`, decisiones tomadas en clarify, resultado de la validación y dudas que siguen abiertas y necesitan decisión humana. Indicar que quedan cambios sin commitear, a cargo de `specify-close`.
