---
name: plan
targets: ["*"]
description: "Ejecuta la fase plan de la metodología SDD Umbrella (v8) como Arquitecto: crea la rama del plan y la vincula a los issues de plan, fija el stack por submódulo, ejecuta /speckit.plan desde la raíz con un plan único con una sección por historia de usuario, exige el proceso desde el punto de vista del usuario y del sistema (diagramas Mermaid con interacción entre capas de submódulos y flujo de datos), actualiza el Vault en draft con notas atómicas, enlaza cada issue de plan con su sección y valida el plan contra la spec, la constitution y el Vault. Úsala después de specify-close y antes de analyze."
---

# plan

> **Antigravity:** los subagentes se invocan con `invoke_subagent`; equivalencias de herramientas, `CLAUDE.md`/`AGENTS.md` y `/speckit.*` según la regla `sdd-antigravity-runtime` del plugin.

Cubre solo `plan`. `analyze`, `tasks` y `taskstoissues` son otras fases. No hace commit ni push: eso lo hace el cierre de la fase.

## Delegación
El contexto principal no lee código ni ejecuta `git`, `gh` ni el MCP de GitHub:
- `context-scout`: Vault y grafos.
- `git-reader`: issues, PR de la especificación, estado de repos y ramas.
- `git-operator`: creación de la rama del plan y su vínculo con los issues.
- `issue-manager`: enlace del plan en cada issue `PL`.

## Entradas (preguntar si faltan, nunca asumir)
- **Especificación:** su rama, o el número del issue `SP-xxx`.
- **El resto no se pregunta:** origen (USR, RFR o HFR), issue `SP`, rama base, submódulos afectados, issues de plan (`PL`) con su historia de usuario y notas del Vault se leen del bloque "Metadatos SDD" de la spec. Si falta algo, es un bloqueo: informarlo, no completarlo por suposición.
- **Stack (solo submódulos NUEVOS):** lo indica el Arquitecto por submódulo (ver paso 4).

## Pasos (en orden)

### 1. Pre-chequeos (en una sola llamada de lectura)
Con `git-reader` en **UNA SOLA INVOCACIÓN** agrupada:
- `issue` sobre el `SP` y los `PL`: el `SP` está abierto y es el padre de los `PL`, y existen los issues de plan que lista el bloque "Metadatos SDD".
- `pr` de la especificación (rama de la especificación → rama base): fusionado. Si no lo está, es un bloqueo, porque la rama del plan nace de la base y necesita la spec.
- `estado-repos` sobre la raíz y el Vault: sin cambios sin commitear, salvo configuración SDD pendiente (p. ej. de un `init` corrido sobre una rama base), que pasa a la rama del plan al crearla y la commitea `plan-close`.

En el contexto principal: existe la constitution y el `CLAUDE.md` de cada submódulo afectado, y el bloque "Metadatos SDD" está completo.

Si algo falla, detenerse e informar; no corregir en silencio.

### 2. Rama del plan (primer paso de trabajo)
Todo el trabajo de esta fase se hace en una rama propia del plan.
- **Nombre:** sugerir al usuario `pl-<rama-de-la-especificacion>` (p. ej. `pl-usr-carga-masiva-clientes`), en minúsculas y con guiones, y esperar su confirmación o corrección. [CONFIRMAR: formato del nombre.]
- **Base:** la rama base del origen (`develop`, `release` o `main`/`master`) en el repo raíz, NO la rama de la especificación: la spec ya está en la base por el PR fusionado. No se crean ramas del plan en los submódulos: el plan no cambia su código.
- **Crear y vincular:** con confirmación, `git-operator` en **UNA SOLA INVOCACIÓN**:
  - `crear-rama` en la raíz desde la base, con checkout, vinculada al issue `SP`;
  - `vincular-rama` de esa misma rama a todos los `PL` de la especificación.
- **Comprobación:** `git-reader` (`rama` e `issue` en una llamada): la raíz está en la rama del plan y la rama aparece en Development del `SP` y de cada `PL`.
- Trabajar SOLO sobre esa rama durante toda la fase. Los commits de esta fase (que hace el cierre) van a esta rama.
- [VERIFICAR: Spec Kit puede ubicar la spec por el nombre de la rama activa; si no la encuentra desde la rama del plan, indicar la especificación de forma explícita (por ejemplo con la variable o el parámetro que ofrezca la versión instalada) en lugar de renombrar la rama.]
- **Estados:** esta skill no cambia estados en el proyecto de GitHub; los mueve `plan-close`.
- El Vault tiene rama única `main`: sus notas de esta fase se escriben ahí, no en la rama del plan.

### 3. Contexto (en una sola llamada)
- Lanzar `context-scout` en **UNA SOLA INVOCACIÓN** con la spec y el propósito (planificar): lee del Vault y de los grafos de todos los submódulos responsables solo lo necesario en una pasada integral. El contexto principal NO lee el código.
- Leer el `CLAUDE.md` de cada submódulo afectado para fijar la arquitectura obligatoria: en NUEVO, DDD + Clean + Hexagonal con slice por módulo (backend) o combinada con MVP o hooks (frontend, mobile); en LEGACY, la arquitectura detectada.

### 4. Stack por submódulo
- **Submódulo LEGACY:** el stack está en la constitution (lo registró `init`). El plan lo respeta. Si falta en la constitution, es un bloqueo. El plan no puede introducir otro lenguaje, framework o librería principal sin que el usuario confirme y se actualice la constitution.
- **Submódulo NUEVO:** el stack lo indica el Arquitecto por submódulo. Si todavía no está registrado, preguntárselo; no proponerlo en su lugar. Una vez confirmado, registrarlo en el `CLAUDE.md` del submódulo y en la constitution para los planes siguientes. Ambos son configuración SDD y se commitean en la rama de trabajo activa: la constitution en la rama del plan (lo hace `plan-close`); el `CLAUDE.md` del submódulo, que no tiene rama de plan, queda pendiente y lo sube su rama de tarea (`implement-close`).

### 5. Ejecutar plan
- Verificar con `specify --help` el comando exacto de la versión instalada.
- Desde la raíz y en la rama del plan, ejecutar `/speckit.plan` indicando: el stack por submódulo, la arquitectura obligatoria de cada uno, y que el plan sea UNO por especificación, con una sección por cada historia de usuario (identificada con el mismo identificador y título que usa su issue `PL`). En cada historia de usuario, exigir explícitamente que el Punto de vista del sistema detalle la interacción exacta entre las capas de los submódulos involucrados y el flujo exhaustivo de datos (DTOs/payloads de entrada, salida y transformaciones).
- Las decisiones técnicas que no estén cubiertas por el stack ni por la constitution se le preguntan al usuario; el agente no decide por él.
- Asegurar que la ejecución de `/speckit.plan` genere la suite COMPLETA de artefactos estándar de Spec Kit en la carpeta de la especificación (`specs/<feature>/`):
  - `plan.md`: Plan arquitectónico maestro.
  - `research.md`: Diagnóstico de causa raíz, trade-offs técnicos, alternativas evaluadas y justificación de arquitectura.
  - `data-model.md`: Entidades de dominio, tablas de BD / colecciones, UDFs, triggers o DTOs afectados.
  - `contracts/`: Contratos de interfaz (OpenAPI/Swagger YAML para endpoints REST o esquemas para eventos/mensajería).
  - `quickstart.md`: Guía de verificación paso a paso, comandos de testing y criterios de validación para desarrolladores.

### 6. Contenido obligatorio del plan (regla de la constitution)
La fase plan NO se limita a un documento aislado ni a un resumen genérico. Debe generar y completar la suite íntegra de artefactos en `specs/<feature>/`:
1. **`plan.md` (Plan arquitectónico maestro):**
   - **Estructura de Archivos y Proyecto:** sección obligatoria (`## Estructura de Archivos y Proyecto` / `Project Structure`) con la estructura concreta de archivos y cambios desglosada por cada submódulo afectado.
   - **Doble punto de vista por historia de usuario:** para cada historia de usuario (con su identificador y título de issue `PL`), mostrar obligatoriamente:
     - **Punto de vista del usuario:** cómo queda el proceso (pasos, pantallas o interacciones y resultados). Diagrama de secuencia en Mermaid con su explicación breve.
     - **Punto de vista del sistema (Interacción entre capas y flujo de datos):**
       - **Interacción entre capas de los submódulos:** Debe reflejar con precisión las capas arquitectónicas reales (Clean Architecture, Hexagonal, MVP, DDD) de cada submódulo involucrado:
         - *Frontend / Mobile:* UI / Vistas / Componentes $\leftrightarrow$ Presenters / Custom Hooks $\leftrightarrow$ Casos de Uso / Aplicación $\leftrightarrow$ Puertos / Repositorios $\leftrightarrow$ Adaptadores / RemoteServices / DataSources locales (SQLite, RAM).
         - *Backend:* Controladores / Endpoints $\leftrightarrow$ Puertos de Entrada / Casos de Uso $\leftrightarrow$ Entidades de Dominio / Reglas / Servicios de Dominio $\leftrightarrow$ Puertos de Salida $\leftrightarrow$ Adaptadores de Infraestructura (Keyed Services, repositorios SQL, Service Layer, etc.).
         - *Sistemas externos:* SAP B1 Service Layer, Bases de datos HANA/MSSQL, servicios de mapas o APIs externas.
       - **Flujo de los datos (Data Flow):** Debe detallar qué información viaja en cada paso:
         - Datos y DTOs de entrada en cada invocación (Request DTOs, Commands, Query Filters).
         - Transformaciones y mapeos de datos en los límites entre capas (ej.: Request DTO $\to$ Command $\to$ Domain Entity $\to$ Payload Service Layer).
         - Datos y DTOs de respuesta (Resultados, Entidades, Response DTOs, ViewModel / UI State de retorno).
         - Manejo del flujo de errores y excepciones de negocio entre capas.
       - **Diagrama Mermaid obligatorio:** Se debe utilizar preferentemente un **Diagrama de Secuencia (`sequenceDiagram`)** donde los participantes estén agrupados por submódulo (`box "Submódulo"`) y representen las capas internas exactas con los nombres de métodos y DTOs en llamadas y retornos, o un **Diagrama de Flujo (`flowchart`) con subgrafos (`subgraph`) por submódulo y capa**, identificando claramente los DTOs y payloads en cada conector.
       - **Explicación breve:** Desglose explicativo del ciclo de vida del dato paso a paso a través de las capas y submódulos.
2. **`research.md`:** Diagnóstico de causa raíz, análisis de trade-offs técnicos, alternativas evaluadas y justificación arquitectónica documentada.
3. **`data-model.md`:** Entidades de dominio, diagramas de datos, tablas de BD / colecciones, campos, tipos, UDFs, triggers o DTOs involucrados.
4. **`contracts/`:** Directorio con los contratos formales de interfaz (OpenAPI/Swagger YAML para endpoints REST, o esquemas JSON/Avro/Proto para eventos y mensajería).
5. **`quickstart.md`:** Guía paso a paso de verificación local, comandos de testing, endpoints o flujos de prueba y criterios de validación para desarrolladores.

Mermaid es gratuito y es el formato por defecto. Si no se puede usar en el entorno, basta con el proceso en un listado ordenado. Si falta algún punto de vista o algún artefacto de la suite, completarlo antes de seguir.

### 7. Arquitectura
Comprobar que la estructura de archivos del plan, por submódulo, respete la arquitectura obligatoria: capas y dependencias (`domain` sin dependencias, `application` solo de `domain`, `infrastructure` implementa los puertos), slice por módulo, y no acceder a las entrañas de otro módulo. Si el plan se aparta, listar la desviación con su origen y corregirla con confirmación del usuario.

### 8. Vault en `draft`
- Escribir en el Vault las decisiones de diseño y arquitectura que introduce el plan: `02_Architecture/`, `03_Modules/` y, si el plan ajusta reglas de negocio, `04_Business_Rules/`.
- Atomizar: cada decisión, módulo o regla va en su propia nota, con su propio `status` en el frontmatter. No agrupar varias en una misma nota.
- Cada nota nueva lleva `status: draft`, enlaces `[[...]]` a las notas relacionadas e indica el submódulo responsable.
- Si el plan cambia algo `approved`: crear una nota nueva en `draft` que describa el cambio planificado (qué cambia, de qué a qué y por qué) y enlace a la nota `approved`. La `approved` NO se modifica; se actualiza durante la implementación y pasa directo a `approved`.
- Si una nota `approved` agrupa varias reglas y el plan afecta solo a una, extraer esa regla a su propia nota atómica `approved` (mismo contenido), dejando el enlace en la original. Pedir confirmación al usuario antes de reestructurar una nota `approved`.
- Registrar cada nota en `01_Index/index.md` (resumen de una línea) y el cambio en `06_Logs/log.md` (append-only).
- NO guardar el plan ni otras especificaciones ni `graphify-out/` en el Vault. Las notas pasan a `approved` al crear las tareas, no en esta fase.
- Usar solo las herramientas nativas del editor (Write y Edit). Prohibido usar scripts secundarios para escribir notas.

### 9. Issues de plan (actualización en lote)
- Con confirmación del usuario, invocar a `issue-manager` (`actualizar`) en **UNA SOLA INVOCACIÓN** para actualizar todos los issues `PL` de la especificación a la vez, agregando a cada uno el enlace al plan y a la sección de su historia de usuario en una sección fechada. Solo issues abiertos.
- El issue `SP` padre no se modifica ni se cierra.

### 10. Metadatos
Actualizar el bloque "Metadatos SDD" de la spec con: la rama del plan, la ruta del plan, la sección que corresponde a cada issue `PL`, el stack fijado por submódulo y las rutas de las notas del Vault creadas en este paso.

### 11. Validación
Antes de terminar, comprobar el plan contra:
- **Suite completa de artefactos:** validar explícitamente que los 5 artefactos de Spec Kit en `specs/<feature>/` estén presentes, no vacíos y completos: `plan.md` (con doble punto de vista Mermaid detallando la interacción entre capas de submódulos y flujo de datos, además de estructura de archivos por submódulo), `research.md`, `data-model.md`, `contracts/` (con los esquemas o especificaciones de contratos) y `quickstart.md`.
- **La spec:** que cada requisito y cada historia de usuario esté cubierto y que no haya funcionalidad que la spec no pida.
- **La constitution:** principios, stack, arquitectura obligatoria y contenido obligatorio del paso 6 (en particular la interacción multicapa y flujo de datos en el punto de vista del sistema).
- **El Vault:** que no contradiga reglas `approved`, salvo los cambios ya registrados en una nota `draft` enlazada, y que sea congruente con las `draft` que acaba de escribir.

Si hay inconsistencias o falta algún artefacto de la suite, listarlas con su origen (qué parte del plan choca con qué o qué artefacto falta) y proponer la corrección. No modificar el plan ni el Vault sin confirmación del usuario.

## Salida
Reporte corto: rama del plan creada y vinculada a qué issues, lista con la ruta de cada uno de los artefactos generados de la suite Spec Kit (`plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`), secciones por historia de usuario, stack fijado por submódulo, confirmación de los dos puntos de vista con su diagrama o listado por historia (verificando interacción entre capas de los submódulos y flujo de datos), desviaciones de arquitectura encontradas, notas del Vault creadas en `draft`, issues de plan actualizados, resultado de la validación de la suite completa y dudas que necesitan decisión humana. Indicar que quedan cambios sin commitear en la rama del plan, a cargo del cierre de la fase.
