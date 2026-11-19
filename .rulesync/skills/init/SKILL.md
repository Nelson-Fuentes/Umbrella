---
name: init
targets: ["*"]
description: "Inicializa un proyecto bajo la metodología SDD Umbrella (v8): instala Spec Kit (integración agy) y sus librerías, ejecuta su compose, crea CLAUDE.md y .agents/AGENTS.md en la raíz y en cada submódulo, asegura las ramas de Git Flow y escribe las reglas de Vault/Graphify y de arquitectura. Úsala al arrancar un proyecto nuevo o al incorporar uno legacy."
---

# init

> **Antigravity:** los subagentes se invocan con `invoke_subagent`; equivalencias de herramientas, `CLAUDE.md`/`AGENTS.md` y `/speckit.*` según la regla `sdd-antigravity-runtime` del plugin.

## Delegación de git y GitHub
El contexto principal no ejecuta `git`, `gh` ni el MCP de GitHub. Lo hace a través de:
- `git-reader`: toda lectura (estado de repos, ramas, proyecto).
- `git-operator`: ramas, commits, push y submódulos.
- `github-setup`: proyecto de GitHub (estados, campos), etiquetas base y repositorio del Vault.

Las operaciones de escritura se confirman antes con el usuario.

## Entradas (preguntar si faltan, nunca asumir)

- **Modo:** NUEVO | LEGACY
- **Ruta del Vault:** por defecto `/vault`
- **Submódulos de código:** lista con su tipo: `backend` (apis, servicios, tareas, rpc) | `frontend` (web) | `mobile`
- **Stack de cada submódulo:** en NUEVO no se pide aquí: lo indica el Arquitecto por submódulo al ejecutar `plan`. En LEGACY se detecta en este init (lo hace `legacy-analyzer`) y queda registrado en la constitution.
- **Nombre de la rama de producción:** `main` o `master`
- **Proyecto de GitHub:** dueño y número del proyecto al que se vincularán los issues (lo usa `issue-manager`, que lleva un correlativo por proyecto). Se verifica con `github-setup` (`verificar-proyecto`).
- **Sigla de 3 letras por repositorio** (p. ej. `BCK`, para el título de los issues), incluido el repositorio de especificaciones, cuya sigla es `SPC`.

## Pasos (en orden)

### 1. Instalación de Spec Kit
- Instalar Spec Kit y todas las librerías necesarias: CLI `specify`, preset `spec-kit-preset-multi-repo-branching` y extensión GitHub con `default_grouping: "user-story"`.
- En Antigravity, inicializar con la integración `agy`: `specify init . --integration agy` (o `specify integration install agy` si Spec Kit ya está inicializado). Los comandos quedan como skills en `.agents/skills/speckit-<comando>/`.
- Verificar con `specify check` y `specify --help` los comandos exactos antes de ejecutarlos.
- Instalar `graphifyy` (con dos "y"). PROHIBIDO `graphify-cli`.

### 2. Compose de Spec Kit
- Ejecutar internamente el compose de Spec Kit desde la raíz, para combinar el preset multi-repo y la extensión GitHub en la configuración del repo de especificaciones.
- Registrar en la salida qué comando se ejecutó y su resultado.
- El comando es `compose`. Antes de ejecutarlo, comprobar su sintaxis y opciones exactas en la versión instalada (`specify --help`, `specify compose --help`) y no inventar flags.
- [VERIFICAR: la documentación oficial consultada no lista un comando `compose`; lo más cercano es `specify bundle` (compone extensiones, presets y workflows en una unidad instalable). Si la versión instalada no trae `compose`, detener y consultar al usuario antes de usar otra vía.]

### 3. Ramas (raíz y cada submódulo)
- `git-reader` (`estado-repos`) sobre el repo de especificaciones y cada submódulo de código: existencia de la rama de producción (`main` o `master`, la que ya exista), `develop` y `release`, y cambios sin commitear.
- Mostrar al usuario qué falta. Con su confirmación, `git-operator` (`crear-ramas-base`) crea las que falten desde la rama de producción y las sube. No se crea la otra rama de producción ni se reescribe historia.
- Excepción: el Vault usa rama única `main`.

### 3b. Proyecto de GitHub
Con confirmación del usuario, `github-setup`:
- `verificar-proyecto`: existe y hay acceso.
- `configurar-estados`: `Backlog` → `Especificado` → `Planificando` → `Planificado` → `Implementando` → `Implementado` → `En Revisión` → `Con Observaciones` → `Done`, insertando los que falten tras `Backlog` y conservando los existentes y su orden. `En Revisión`, `Con Observaciones` y `Done` solo los usa el `TK`.
- `campo-estimate`: campo `Estimate` de tipo número (puntos de historia en Fibonacci); lo usa `plan-close`.
- `campo-iteracion`: comprobar el campo de iteración que usa `sprint-close` y crearlo si el usuario lo confirma.
- `etiquetas-base`: `specification` y `plan` en la raíz, `task` en los submódulos, y las de prioridad acordadas.

Quién usa los estados:
- `issue-manager` crea cada `SP`, `PL` y `TK` en `Backlog`.
- `specify-close` mueve el `SP` a `Especificado`.
- `plan-close` mueve cada `PL` a `Planificado`; el `SP` pasa a `Planificando` cuando el primer `PL` llega a `Planificado`, y a `Planificado` cuando todos lo están.
- `implement` mueve el `TK` a `Implementando`; `implement-close` lo mueve a `Implementado` al crear el PR (o, en un retrabajo desde `Con Observaciones`, al agregar los commits de corrección al PR existente). El `PL` pasa a `Implementando` cuando al menos uno de sus `TK` está `Implementado` o más avanzado, y a `Implementado` cuando todos sus `TK` llegaron a `Implementado` o más avanzado. El `SP` sigue la misma regla respecto de sus `PL`, pero solo cuando todos sus `PL` están en `Planificado`.
- `review-pr` mueve el `TK` a `En Revisión` al publicar la revisión del PR en GitHub, y después a `Done` (cerrando el issue) si no quedaron hallazgos publicados, o a `Con Observaciones` si quedaron. Desde `Con Observaciones`, el retrabajo (`implement` + `implement-close`) y una nueva corrida de `review-pr` pueden repetirse hasta llegar a `Done`. Son los únicos estados y el único cierre de issue que no mueven ni afectan al `PL` ni al `SP`: para ellos, un `TK` en `Implementado`, `En Revisión`, `Con Observaciones` o `Done` cuenta igual (ya "hecho" a efectos de sus padres).

### 4. Vault y Graphify (reglas del prompt del Vault)
Crear `/vault` como repo propio y submódulo de la raíz, rama única `main`: con confirmación, `github-setup` (`crear-repo`) y después `git-operator` (`agregar-submodulo`). Aplicar estas reglas, que son las del prompt del Vault de la metodología (Modelo Híbrido: Obsidian LLM Wiki + Graphify, en una sola instrucción).

**Graphify por submódulo de código (solo LEGACY)**
1. Ejecutar `pip install graphifyy` (con dos "y"). PROHIBIDO instalar o ejecutar `graphify-cli`: es un paquete distinto e incompatible.
2. En CADA submódulo de código, analizar todo su código fuente, en cualquier lenguaje que contenga, con extracción AST, y generar dentro de `graphify-out/`:
   - `graph.json`
   - `GRAPH_REPORT.md`
   - `graph.html` (D3 Force-Graph, modo oscuro, fondo `#0b0f19`)
   - `manifest.json`
3. Reglas inviolables:
   - PROHIBIDO decir que Graphify no es compatible con un lenguaje.
   - PROHIBIDO reemplazar `graphify-out/` con Mermaid o HTML personalizado.

**Notas de memoria en el Vault (solo LEGACY)**
- Leer el código y los grafos y volcar en el Vault la lógica de negocio y la información relevante (reglas, flujos, entidades, decisiones).
- NO guardar especificaciones (viven en el repo de especificaciones).
- NO guardar `graphify-out/` en el Vault.
- Cada nota que documente lo YA EXISTENTE lleva `status: approved`.
- Enlazar las notas entre sí y señalar qué submódulo es responsable de cada regla.

**Instrucciones para agentes (NUEVO y LEGACY)**
Se escriben en `CLAUDE.md` y `.agents/AGENTS.md` (ver paso 6):
- LECTURA: leer primero `/vault` (lógica de negocio); decidir qué submódulo es responsable; leer el `graphify-out/` de ese submódulo.
- ACTUALIZACIÓN: actualizar el Vault al cerrar diseño y plan, y cuando la implementación cambie una regla o su forma de implementarse. Regenerar `graphify-out/` del submódulo tras cada merge o rebase.
- ESTADOS: lo escrito en `specify` nace `draft` y pasa a `approved` al crear las tareas; lo actualizado durante la implementación pasa directo a `approved`.
- PROYECTOS NUEVOS: generar `graphify-out/` la primera vez que haya código (por ejemplo, al primer merge a `develop`).

**Reglas de contexto de la metodología**
- El Vault es el qué y el porqué (negocio); `graphify-out/` es el cómo está construido (código).
- `graphify-out/` sigue la rama activa (`feature/*`, `release/*` o `hotfix/*`) y nunca se fusiona a mano.

**Limpieza de artefactos de Graphify**
Tras generar el grafo, eliminar cachés y temporales (`.graphify_detect.json`, `.graphify_python`, `ARCHITECTURE_GRAPH.md`, carpeta `cache/`). `graphify-out/` queda solo con los 4 archivos oficiales. El paquete oficial es `graphifyy` (repo Graphify-Labs/graphify).

**Patrón base: LLM Wiki (Andrej Karpathy)**
El Vault sigue el patrón LLM Wiki (ref: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f#llm-wiki). A diferencia del RAG, que redescubre el conocimiento en cada pregunta, la wiki se compila una vez y se mantiene incrementalmente en Markdown con notas cruzadas `[[...]]`, `log.md` e `index.md`.
- Tres capas: **Raw sources** (inmutables, el código), **Wiki** (notas compiladas por el agente), **Schema** (las reglas de la wiki).
- Roles: Obsidian es el IDE visual, el agente es el mantenedor de la wiki, la wiki es la base de conocimiento compilada.
- Operaciones: **Ingest** (absorber fuentes), **Query** (responder desde `index.md` y las notas), **Lint** (salud de la wiki).

**Estructura del Vault** (adaptada al tipo de proyecto; la raíz del repo `/vault` es la carpeta del proyecto)
```
<NOMBRE_PROYECTO>/
├── Bienvenido.md                  # Inicio: índice rápido y accesos [[...]]
├── 00_Schema/
│   ├── LLM_WIKI_SCHEMA.md         # Protocolo operativo del agente (Ingest, Query, Lint)
│   └── TOKEN_SAVINGS_GUIDE.md     # Metodología de cálculo y registro de tokens
├── 01_Index/
│   ├── index.md                   # Catálogo maestro: resumen de 1 línea y [[enlaces]]
│   └── MOC_Mapa_de_Contenido.md   # Árbol de conocimiento con diagramas Mermaid
├── 02_Architecture/
│   ├── Arquitectura_General.md    # Flujo end-to-end, capas y datos
│   └── Ciclo_de_Vida_Modulo.md    # Estados, hooks/rutas/servicios y rendering/ejecución
├── 03_Modules/                    # Una nota atomizada por módulo/componente/servicio clave
├── 04_Business_Rules/             # Reglas de negocio, esquemas de datos, validadores, formatos
├── 05_Queries_and_Syntheses/      # Análisis técnicos y respuestas a consultas complejas
└── 06_Logs/
    ├── log.md                     # Bitácora cronológica append-only de ingestas y cambios
    └── token_savings.md           # Registro acumulativo de métricas de ahorro de tokens
```
- NUEVO y LEGACY convergen en el mismo esqueleto (carpetas, Schema, Index). En NUEVO queda vacío; en LEGACY además se llena con notas en `03_Modules/`, `04_Business_Rules/` y `02_Architecture/`.
- Los diagramas Mermaid permitidos son los del Vault (MOC, arquitectura); nunca sustituyen a `graphify-out/`.

**Reglas inviolables de edición y contexto**
1. **Revisión de contexto previo (regla #0):** antes de modificar o planificar la implementación de código, consultar el Vault y `GRAPH_REPORT.md` del submódulo, para mantener coherencia.
2. **Herramientas nativas del IDE:** hacer TODAS las modificaciones de código y la creación de archivos Markdown con las herramientas nativas del editor (en Antigravity: `replace_file_content`, `multi_replace_file_content`, `write_to_file`; en Claude Code: Edit y Write).
3. **Prohibido usar scripts secundarios para editar código:** nunca crear ni ejecutar scripts temporales que sobreescriban código del proyecto o notas. Los cambios deben verse como diff exacto en la interfaz del editor.
4. **Git y GitHub solo mediante subagentes:** el contexto principal no ejecuta `git`, `gh` ni el MCP de GitHub; lee con `git-reader` y escribe con `git-operator`, `issue-manager`, `pr-manager`, `release-manager` o `github-setup`, según la responsabilidad.

**Ejecución por modo**
- NUEVO: se crea el esqueleto del Vault y se escriben las instrucciones de agentes; no hay Graphify ni notas de contenido todavía.
- LEGACY: Graphify y notas se ejecutan a través de los subagentes `legacy-analyzer` (paso 5); el contexto principal no lee el código.

### 5. Arquitectura por submódulo

**Modo LEGACY**
- Lanzar un subagente `legacy-analyzer` por submódulo, en paralelo. La lectura del código la hace SIEMPRE el subagente, nunca el contexto principal.
- Cada uno devuelve: arquitectura detectada, stack detectado, convenciones de carpetas y nombres, capas, patrones, y las notas que escribió en el Vault (`status: approved`).
- La arquitectura detectada se escribe en el `CLAUDE.md` y el `.agents/AGENTS.md` de ese submódulo como la que el agente DEBE seguir.
- Ejecutar Graphify en cada submódulo (lo hace el subagente).

**Modo NUEVO: backend** (apis, servicios, tareas, rpc)
DDD + Clean + Hexagonal estricta, con slice vertical por módulo:

```
<modulo>/
  domain/
    entities/
    ports/
    enums/
    exception/
  application/
    port/
    usecases/
    services/
    dto/
    mapper/
  infrastructure/
    database/
    controllers/
    dto/
    mapper/
```
Reglas: `domain` no depende de nada; `application` solo de `domain`; `infrastructure` implementa los puertos. Un módulo no accede a las entrañas de otro; se comunican por puertos o casos de uso.

**Modo NUEVO: frontend (web, mobile, etc.)**
DDD + Clean + Hexagonal combinada con:
- Web: Modelo Vista Presentador (MVP).
- React Native: hooks como capa de presentación.
- Mismo slice por módulo; `domain` y `application` sin dependencias de UI ni de framework; la UI solo habla con presentadores/hooks.

### 6. CLAUDE.md y AGENTS.md
Crear `CLAUDE.md` en la raíz y en cada submódulo, y `.agents/AGENTS.md` en la raíz de cada repo activo (lo consume Antigravity), con el mismo contenido de reglas:

```markdown
# Reglas e Instrucciones del Repositorio

## 0. Repaso de Información Antes de una Modificación
Revisar tanto el vault de Obsidian del proyecto como el grafo de Graphify
(`graphify-out/GRAPH_REPORT.md`) para mantener un contexto completo del proyecto
antes de realizar cualquier modificación o planificación de implementación.

## 1. Actualización Automática de Graphify
- **Regla Inviolable**: Después de realizar cualquier modificación estructural o
  funcional en el código fuente, se DEBE mantener actualizada la carpeta
  `graphify-out/` (`graph.json`, `GRAPH_REPORT.md` y `graph.html` D3) utilizando
  el paquete oficial `graphifyy` (con dos 'y') sin consumo de tokens ($0.00 USD).

## 2. Actualización Automática de Obsidian (LLM Wiki)
- **Regla Inviolable**: Después de realizar cualquier cambio, extensión o
  incorporación en las **reglas de negocio, lógica de dominio, esquemas de datos
  o arquitectura**, se DEBE actualizar el Vault de Obsidian:
  - la nota atomizada correspondiente en `03_Modules/` o `04_Business_Rules/`,
  - `01_Index/index.md` con su resumen de 1 línea y enlaces `[[...]]`,
  - `06_Logs/log.md`, registrando el cambio en modo append-only,
  - el `status` de la nota (`draft` o `approved`), según el flujo de la metodología.

## 3. Git y GitHub solo mediante subagentes
- **Regla Inviolable**: el agente principal no ejecuta `git`, `gh` ni el MCP de
  GitHub. Toda lectura la hace `git-reader`; las escrituras, el subagente
  responsable: `git-operator` (ramas, commits, push, submódulos),
  `issue-manager` (issues y estados), `pr-manager` (PR),
  `release-manager` (versiones, tags y releases) y `github-setup`
  (configuración del proyecto). Toda escritura requiere confirmación del usuario.
```

Además, en el `CLAUDE.md`/`AGENTS.md` incluir las reglas inviolables de edición del paso 4 y las instrucciones de agentes.

- **Raíz:** las "Instrucciones para agentes" del paso 4 completas (lectura, actualización, estados, proyectos nuevos), las reglas de Graphify (`graphifyy`, no `graphify-cli`; prohibido Mermaid/HTML propio), la lectura de código mediante subagente, la delegación de git y GitHub, el flujo Spec Kit, el enlace a la constitution, el proyecto de GitHub y las siglas de repositorio (las consume `issue-manager`).
- **Submódulo:** arquitectura obligatoria (detectada o la de arriba), stack, convenciones, cómo regenerar `graphify-out/`. En cada submódulo crear también `.agents/AGENTS.md` con el mismo contenido que su `CLAUDE.md`.
- Proyectos NUEVOS: instrucción de generar `graphify-out/` la primera vez que haya código (p. ej. primer merge a `develop`).

### 7. Constitution
Escribir la constitution (`/speckit.constitution`; en Antigravity, la skill `speckit-constitution`) con, además de los principios del proyecto, esta regla:

> Al ejecutar el plan, NO basta con estructura de archivos y modelo de datos. El plan debe mostrar el proceso desde dos puntos de vista:
> 1. **Punto de vista del usuario:** cómo queda el proceso (pasos, pantallas o interacciones, resultados). Diagrama de secuencia en Mermaid con su explicación breve.
> 2. **Punto de vista del sistema:** interacción detallada entre las capas de los submódulos involucrados (Clean Architecture / Hexagonal / MVP / DDD: componentes UI, presenters/hooks, casos de uso, dominio, repositorios, adaptadores e infraestructura) y el flujo de los datos (DTOs de entrada/salida, mapeos y transformaciones). Diagrama de secuencia Mermaid multicapa o flujo con subgrafos por capa y submódulo con su explicación breve.

Incluir también la arquitectura obligatoria por tipo de submódulo, las reglas del Vault y la delegación de git y GitHub en subagentes.

**Modo LEGACY:** incluir además el stack detectado de cada submódulo (lenguaje, framework, versiones y librerías clave), tal como lo devolvió `legacy-analyzer`. Es obligatorio: `plan` lo lee de aquí y no puede proponer otro stack sin cambiar la constitution con confirmación del usuario. Escribirlo también en el `CLAUDE.md` y `.agents/AGENTS.md` del submódulo.

### 8. Commit de la inicialización: en la rama de trabajo activa
Lo que genera este init es **configuración SDD**: `CLAUDE.md`, `.agents/AGENTS.md`, la configuración de Spec Kit, la constitution, `.gitmodules` y el puntero del Vault en la raíz, y `graphify-out/` (LEGACY) en los submódulos. No tiene rama propia: se commitea en la rama de trabajo activa de cada repo (especificación `usr-`/`rfr-`/`hfr-`, plan `pl-` o tarea `*-tk-xxx`) y llega a la base con el PR de esa rama.
- **Vault:** siempre `main`. Con confirmación, `git-operator` (`commit` + `push`) de sus notas y su esqueleto directo a `main`.
- **Raíz y submódulos:** `git-reader` (`estado-repos`) da la rama activa de cada uno.
  - **Si es una rama de trabajo:** con confirmación, `git-operator` (`commit` + `push`) de los archivos de configuración SDD, en un commit propio (`chore(init): configuración SDD`), separado de cualquier otro cambio.
  - **Si es una rama base** (producción, `develop` o `release`): NO se commitea en ella. Los cambios quedan pendientes en el árbol de trabajo y los sube la siguiente rama de trabajo que se cree en ese repo:
    - en la raíz, la rama de especificación (`specify` la crea y `specify-close` hace el commit);
    - en cada submódulo, la rama de tarea (`implement` la crea y `implement-close` hace el commit).
- Reportar, por repo, si la configuración quedó commiteada (rama y commit) o pendiente (qué archivos y qué skill la subirá).

## Salida
Reporte final corto: qué se instaló, qué ramas se crearon, si se crearon los estados `Especificado`, `Planificando`, `Planificado`, `Implementando`, `Implementado`, `En Revisión`, `Con Observaciones` y `Done`, el campo `Estimate`, el campo de iteración y las etiquetas base, qué CLAUDE.md y AGENTS.md se escribieron, arquitectura fijada por submódulo, configuración SDD commiteada (rama y commit) o pendiente por repo, y pendientes que requieren decisión humana.
