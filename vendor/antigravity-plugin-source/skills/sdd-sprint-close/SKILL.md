---
name: sdd-sprint-close
description: "Cierra el sprint en la metodología SDD Umbrella (v8): en la raíz y en cada submódulo de código, hace el merge de develop a release con su tag y release notes, y, si la semaforización lo permite, el merge de release a main con su tag y release notes. Verifica antes que el sprint esté completo, no reescribe historial y consulta ante cualquier conflicto. Nunca cierra issues. Úsala al terminar el desarrollo del sprint, después de sdd-implement-close."
---

# sdd-sprint-close

> **Antigravity:** los subagentes se invocan con `invoke_subagent`; equivalencias de herramientas, `CLAUDE.md`/`AGENTS.md` y `/speckit.*` según la regla `sdd-antigravity-runtime` del plugin.

Cubre el pase de `develop` a `release` y de `release` a `main`/`master`, con sus tags y release notes. Los hotfix (rama desde `main`, con merge a `main`, `develop` y `release`) son otro flujo y no pasan por esta skill. Cada acción que escribe en GitHub o en una rama protegida requiere confirmación del usuario. NUNCA cierra issues, nunca reescribe historial (sin `--force`, ni `--force-with-lease`, ni rebase) y nunca borra ramas ni tags.

## Delegación
El contexto principal orquesta y decide con el usuario; no ejecuta `git`, `gh` ni el MCP de GitHub:
- `sdd-git-reader`: estado de repos, divergencias, PR e issues del sprint, checks, iteración, semaforización, punteros.
- `sdd-pr-manager`: PR de `develop` → `release`, `release` → producción y `release` → `develop`, y su merge.
- `sdd-release-manager`: versiones (reglas de versionado), release notes, tags y releases.
- `sdd-git-operator`: punteros de los submódulos en la raíz y commits del grafo.

## Entradas (preguntar si faltan, nunca asumir)
- **Sprint:** no se pregunta, es siempre el sprint actual. `sdd-git-reader` (`proyecto`) devuelve la iteración cuyo rango de fechas incluye hoy (su nombre se usa en las release notes y en el reporte). Se muestra en el reporte inicial; si el proyecto no tiene campo de iteración, o ninguna iteración (o más de una) incluye la fecha de hoy, es un bloqueo: informarlo, no inventar el sprint. (El campo lo crea `sdd-github-setup` desde `sdd-init`.)
- **Alcance:** `release` (solo `develop` → `release`), `main` (solo `release` → `main`/`master`) o `ambos`, cada etapa con su propia compuerta. El paso a `main` puede no hacerse en cada sprint, según la semaforización.
- **Repositorios:** la raíz de especificaciones y los submódulos de código que se incluyen (por defecto, todos los que tengan cambios; el paso 2 los detecta). El Vault no participa: tiene rama única `main`.
- **Proyecto de GitHub** (dueño y número), para leer issues y estados.
- **Versión de cada repositorio:** se propone en el paso 3 y la confirma el usuario.

## Pasos (en orden)

### 1. Pre-chequeos
`sdd-git-reader` (`estado-repos`, con `fetch`) sobre la raíz, los submódulos y el Vault:
- Existen en cada repositorio la rama de producción (`main` o `master`, la que exista), `release` y `develop`.
- No hay cambios sin commitear. La configuración SDD pendiente no bloquea: se informa y no se commitea aquí (la sube la siguiente rama de trabajo del repo); los commits de esta skill incluyen solo las rutas que les corresponden. Las tres ramas están al día con su remota; si no, `sdd-git-operator` (`actualizar-rama`, solo fast-forward) con confirmación.
- El lector y los gestores informan si `gh` (o el MCP de GitHub) no está disponible o faltan permisos para crear PR, tags y releases.
- Si algo falla, detenerse e informar; no corregir en silencio.

### 2. Estado del sprint (solo lectura)
Con `sdd-git-reader`, por cada repositorio:
- `divergencia` `develop` → `release`: commits y PR que `release` todavía no tiene. Si no hay nada pendiente, ese repositorio se omite en la etapa.
- `divergencia` `release` → producción: commits y PR que producción todavía no tiene, incluidos los commits de fix hechos directo en `release` (RFR).
- **Divergencia a la inversa:** commits de `release` que `develop` no tiene (fixes de release). Si los hay, avisar: deben volver a `develop` o se perderán en el siguiente ciclo (paso 7).
- `pr` abiertos hacia `develop` o `release` e `issues-proyecto` del sprint: `TK` que no están en `Implementado`, y `PL` y `SP` con trabajo sin terminar. Mostrarlos al usuario; no se bloquea el pase por esto, pero el usuario debe confirmar que lo que queda fuera es intencional.
- `checks` de cada rama (último commit). Una rama con checks fallando es un bloqueo hasta que el usuario decida.

### 3. Versiones y tags
- `sdd-release-manager` (`proponer-versiones`) con el movimiento de cada repositorio. Las reglas de versionado (formato `vMM.mm.pp`, qué número sube en cada movimiento, base de cálculo) viven en `sdd-release-manager`; en resumen: `develop` → `release` sube el segundo número, `release` → producción sube el primero, y los fixes suben el tercero.
- **Secuencia independiente por repositorio:** Cada submódulo y la raíz llevan su propia secuencia de tags según su historial y movimientos particulares. NO existe la regla de forzar la unificación de versiones entre repositorios (si coinciden es circunstancial). Cada repositorio con cambios integrados en la etapa genera su propio tag y pre-release.
- Mostrar su tabla (repositorio, movimiento, versión más alta actual, tag propuesto, si ya existe) para una sola confirmación del usuario.
- Los tags de los fixes (RFR, HFR) no los crea esta skill sino `sdd-fix-release`, después de su merge; la base de cálculo ya los incluye.

### 4. Etapa `develop` → `release` (alcance `release` o `ambos`)
Orden: primero los submódulos de código, al final la raíz, para que los punteros de la raíz apunten a commits que ya existen en `release`.
Para cada repositorio con cambios pendientes, con confirmación del usuario:
1. `sdd-pr-manager` (`crear`): PR de `develop` a `release`, con un cuerpo que liste los issues y PR incluidos (sin palabras de cierre automático) y el resultado de los checks.
2. `sdd-pr-manager` (`fusionar`): merge commit (sin squash ni rebase, para conservar el historial de `develop`). Si devuelve conflictos, detenerse y consultar al usuario; no resolverlos por su cuenta.
3. `sdd-release-manager` (`redactar-notas`), revisión del usuario (paso 6), y después `crear-tag` sobre el commit de merge en `release` y `publicar-release` como pre-release.
4. En la raíz, `sdd-git-operator` (`actualizar-puntero`) de cada submódulo al commit fusionado en su `release`, en el mismo PR de la raíz o en uno propio (rama auxiliar desde `develop` de la raíz y PR con `sdd-pr-manager`). El puntero del Vault apunta siempre a `main`. [CONFIRMAR: mecanismo exacto, porque `release` es una rama protegida.]

### 5. Compuerta de la semaforización (antes de `release` → `main`)
Aplica solo al alcance `main` o `ambos`. `sdd-git-reader` (`issues-proyecto`, tipos RFR y HFR, abiertos) devuelve cada fix con su color y, en los amarillos, la aprobación del PO registrada en el issue:
- 🔴 **Rojo abierto:** bloquea el paso a `main`.
- 🟡 **Amarillo abierto:** bloquea, salvo que el propio issue tenga registrada la aprobación del PO para este sprint. Mostrar la aprobación; no darla por hecha.
- 🟢 **Verde abierto:** no bloquea.
Mostrar al usuario cada issue con su color, su estado y su aprobación del PO. Si algo bloquea, NO se hace la etapa `main`: reportarlo y terminar la skill con lo ya hecho en `release`. Un issue bloqueante solo se desbloquea resolviéndolo o con la aprobación del PO en el issue, nunca por decisión de la skill.

### 6. Release notes
Las redacta `sdd-release-manager` (`redactar-notas`) antes de crear cada release (pasos 4 y 7), con el rango y el contenido que define para cada movimiento, y el usuario las revisa antes de publicar. Hay una release en `release` y otra en `main`/`master`, por repositorio. El contexto principal le pasa el nombre del sprint, los fixes abiertos que no bloquearon (para "problemas conocidos") y, en la raíz, las versiones de los submódulos incluidas.

**Reglas obligatorias de contenido y redacción:**
- **Solo lo REALMENTE implementado en código:** Las release notes deben detallar exclusivamente las funcionalidades y correcciones cuyo código fuente fue efectivamente implementado, probado y fusionado en los submódulos (PRs y tareas `TK` completadas).
- **Prohibido asumir especificaciones como código:** NUNCA describir especificaciones (`SP`) o planes (`PL`) como funcionalidades entregadas si sus tareas de código (`TK`) no han sido implementadas aún en los submódulos. Si en este ciclo solo se trabajaron correcciones de errores (fixes / RFR), las release notes deben enfocarse exclusivamente en los fixes resueltos.
- **Entregables de diseño/especificación:** Si en la raíz umbrella se completaron especificaciones o planes documentales (`SP`/`PL`) pendientes de codificación, se deben agrupar en una sección separada claramente titulada: *"Entregables de Especificación y Diseño (Sin código implementado en esta entrega)"*.
- **Lenguaje accesible para usuarios no técnicos:** Las notas deben ser 100% legibles para usuarios finales y de negocio (despachadores, planificadores, operadores). Evitar entrar en detalles técnicos internos innecesarios (nombres de DTOs, métodos, procedimientos SQL internos, fórmulas matemáticas, librerías internas).
- **Estructura por ítem para el usuario:**
  1. **¿Qué pasaba antes?** (El problema o bloqueo operativo real que sufría el usuario).
  2. **¿Cómo funciona ahora?** (La solución y los beneficios operativos concretos que obtiene).
  3. **Trazabilidad:** Referencia sobria a los PRs e issues asociados.

### 7. Etapa `release` → `main` (alcance `main` o `ambos`, si la compuerta lo permite)
Mismo orden y reglas que el paso 4, con `main` (o `master`) como destino:
1. `sdd-pr-manager`: PR de `release` a la rama de producción y merge commit; consulta ante conflictos.
2. `sdd-release-manager`: notas, `crear-tag` sobre el commit de merge en producción y `publicar-release` (no pre-release).
3. En la raíz, `sdd-git-operator` (`actualizar-puntero`) de los submódulos al commit fusionado en su rama de producción.
4. **Fixes de release hacia `develop`:** si el paso 2 encontró commits en `release` que `develop` no tiene, proponer un PR de `release` a `develop` (`sdd-pr-manager`, `crear` y `fusionar` con merge commit) y hacerlo con confirmación; si hay conflictos, consultar. [CONFIRMAR: si los fixes de release vuelven a `develop` en este paso o por otra vía.]

### 8. Después del merge
- **Grafo:** `graphify-out/` sigue la rama activa y se regenera tras cada merge. Con confirmación, regenerar el de cada submódulo en `release` y en la rama de producción, y subirlo con `sdd-git-operator`. [VERIFICAR: si `graphify-out/` se versiona en cada rama o se regenera por un hook o CI; en ese caso omitir este paso.]
- **Sincronización de ramas:** las demás ramas nacidas de `develop` deben actualizarse con rebase tras un merge a `develop`. Esta skill no las toca ni reescribe historial: `sdd-git-reader` (`divergencia`) lista las ramas abiertas que quedaron desactualizadas, para que el Desarrollador las sincronice. [CONFIRMAR: ¿esto es automatizable por CI?]
- **Issues:** no se cierra ninguno. `sdd-git-reader` (`issues-proyecto`) lista los `SP` y `PL` en estado `Implementado` incluidos en el sprint, para que el usuario los cierre manualmente si corresponde.

### 9. Verificación
Leyendo el remoto, por repositorio: `sdd-git-reader` (`divergencia` y `submodulos`) confirma que los merges están y que los punteros de la raíz son los esperados; `sdd-release-manager` (`verificar`) confirma que cada tag existe y apunta al commit esperado y que cada release existe con sus notas y el tipo correcto (pre-release en `release`, normal en `main`). Corregir lo que no haya quedado (solo agregando, nunca reescribiendo); si algo no se puede, reportarlo.

## Salida
Reporte corto con una fila por repositorio: PR de cada merge (número y enlace), tag y release creados en `release` y en `main`, y qué se omitió y por qué. Después: el resultado de la compuerta de la semaforización con los issues que bloquean, los fixes devueltos a `develop`, las ramas desactualizadas y los `SP` y `PL` candidatos a cerrar. Veredicto:
- **SPRINT CERRADO:** las etapas pedidas se completaron.
- **CIERRE PARCIAL:** qué etapas se hicieron y cuáles quedaron pendientes, con el motivo (por ejemplo, un rojo abierto que bloquea el paso a `main`).
- **NO CERRADO:** lista de bloqueos, cada uno con qué falta, dónde y quién lo resuelve.
