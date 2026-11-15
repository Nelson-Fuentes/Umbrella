---
name: fix-release
targets: ["*"]
description: "Después de que un PR de fix (RFR u HFR) se fusiona en release o en main/master de la metodología SDD Umbrella (v8), crea su tag (tercer número +1) y su release de GitHub con notas, actualiza el puntero y el tag de la raíz cuando el fix es de un submódulo, propone devolver el fix a las demás ramas y deja un comentario con la versión en los issues. Nunca cierra issues. Úsala al fusionarse el PR de un fix, o para varios PR de fix ya fusionados."
---

# fix-release

> **Antigravity:** los subagentes se invocan con `invoke_subagent`; equivalencias de herramientas, `CLAUDE.md`/`AGENTS.md` y `/speckit.*` según la regla `sdd-antigravity-runtime` del plugin.

Cubre el tag y la release de los fixes que entran directo a `release` o a `main`/`master`: fix de release (RFR) y hotfix (HFR). Los pases de sprint (`develop` → `release` y `release` → `main`) son de `sprint-close`. Cada acción que escribe en GitHub o en una rama protegida requiere confirmación del usuario. NUNCA cierra issues, nunca reescribe historial (sin `--force`, ni `--force-with-lease`, ni rebase) y nunca borra ramas ni tags.

Se ejecuta cuando el PR YA está fusionado: `implement-close` termina al crear el PR y no tagguea. La invoca el usuario, o un hook o CI que la dispare al fusionarse el PR.

## Delegación
El contexto principal orquesta y decide con el usuario; no ejecuta `git`, `gh` ni el MCP de GitHub:
- `git-reader`: PR, issues, tags existentes, estado de repos, divergencias, punteros.
- `release-manager`: versión (reglas de versionado), notas, tag y release.
- `git-operator`: rama auxiliar y puntero del submódulo en la raíz.
- `pr-manager`: PR del puntero en la raíz y PR de devolución a otras ramas.
- `issue-manager`: comentarios de trazabilidad.

## Entradas (preguntar si faltan, nunca asumir)
- **PR de fix fusionado:** repositorio y número, o el issue `TK` o `SP` del fix. Pueden ser varios: se procesan de a uno, en el orden en que se fusionaron.
- **El resto no se pregunta:** tipo (RFR u HFR), color de la semaforización, rama afectada, tag donde se identificó y el `SP`, `PL` y `TK` del fix se leen (con `git-reader`, `pr` e `issue`) del título y cuerpo del PR y del issue, y del bloque "Metadatos SDD" de la spec. Si falta algo, es un bloqueo: informarlo, no completarlo por suposición.

## Pasos (en orden)

### 1. Pre-chequeos
Con `git-reader`:
- `pr`: el PR está **fusionado** y su base es `release` o `main`/`master`. Si la base es `develop` (un USR) o cualquier otra rama, no corresponde: reportarlo y terminar. Los PR de `sprint-close` tampoco pasan por aquí.
- `issue`: el `TK` o el `SP` del PR es de tipo RFR u HFR. Si no se puede determinar, preguntar.
- `tags` con el commit de merge: si ya tiene tag, el fix ya está tagueado: informar el tag y terminar.
- `estado-repos` (con `fetch`): la rama base está al día con su remota. La configuración SDD pendiente no bloquea: se informa y no se commitea aquí.
- Si algo falla, detenerse e informar; no corregir en silencio.

### 2. Versión
- `release-manager` (`proponer-versiones`, movimiento `fix`): tercer número +1 sobre la versión más alta del repositorio (reglas en `release-manager`).
- Con varios PR, la versión de cada uno se calcula después de crear el tag del anterior, de a uno, para que nunca se repita.
- Mostrar al usuario la tabla (repositorio, PR, rama, versión más alta actual, tag propuesto) para una sola confirmación.

### 3. Tag
- `release-manager` (`crear-tag`) sobre el commit de merge del PR en su rama base (no sobre la punta de la rama, si hubo commits posteriores). Mensaje: título del fix, prioridad con su color y número del PR.

### 4. Release de GitHub
- Hay una release en `release` y otra en `main`/`master`, por repositorio. Cada fix crea la suya, desde el tag que acaba de crear.
- `release-manager` (`redactar-notas`, movimiento `fix`): rango desde el tag inmediatamente anterior de esa rama hasta el nuevo, con el contenido de notas de fix que define (versión, fecha, rama, tipo, qué se corrigió con `SP`, `TK`, PR, color y tag de identificación, impacto, y otros cambios del rango sin tag). El usuario las revisa.
- `release-manager` (`publicar-release`): en `release`, pre-release; en `main`/`master`, release normal (latest si es la versión más alta).

### 5. Raíz
La raíz fija el conjunto de punteros de los submódulos, y cada tag de la raíz corresponde a un conjunto concreto.
- **Si el fix es de un submódulo:** con confirmación,
  1. `git-operator` (`crear-rama` auxiliar en la raíz desde la misma rama base, y `actualizar-puntero` del submódulo al commit tagueado, con `push`);
  2. `pr-manager` (`crear` y, con confirmación, `fusionar`) hacia esa rama base;
  3. ese PR cuenta como un PR de fix: `release-manager` sube el **tercer número** de la raíz (pasos 2 a 4 sobre los tags de la raíz), con su propia release, que incluye las notas de este fix y la lista de versiones de los submódulos.
  - El puntero del Vault apunta siempre a `main`.
- **Si el fix es de la propia raíz** (PR de especificaciones de un fix hacia `release` o `main`/`master`): se tagguea la raíz directamente, con los pasos 2 a 4.
[CONFIRMAR: que cada fix de un submódulo genere tag y release también en la raíz.]

### 6. Devolver el fix a las demás ramas
Un fix que entra solo a una rama se pierde en las otras si no se devuelve. `git-reader` (`divergencia`) comprueba si el fix ya está en la otra rama; si ya está, no hacer nada y decirlo. Si no, proponer al usuario, y hacer solo con su confirmación, en cada repositorio, con `pr-manager` (`crear` y `fusionar` con merge commit):
- **RFR** (fusionado en `release`): PR de `release` a `develop`.
- **HFR** (fusionado en `main`/`master`): PR de `main`/`master` a `release` y a `develop`.
- Si hay conflictos, detenerse y consultar al usuario; no resolverlos por su cuenta.
- Estos PR no son fixes nuevos: no suben ningún número ni crean tag, porque el fix ya quedó tagueado. [CONFIRMAR: esta regla, y si esta devolución se hace aquí o en una skill de cierre de hotfix propia.]

### 7. Trazabilidad en los issues (en una sola llamada)
- Con confirmación, `issue-manager` (`comentar`) en **UNA SOLA INVOCACIÓN** para publicar el comentario de trazabilidad (versión, tag, enlace de la release y rama) en todos los issues afectados (`SP` del fix y sus `TK`). No cerrar ningún issue y no cambiar ningún estado.
- Los issues `SP`, `PL` y `TK` del fix los cierra el usuario manualmente.

### 8. Verificación
Leyendo el remoto, por cada tag: `release-manager` (`verificar`) confirma que existe, apunta al commit de merge del PR y su release tiene notas y el tipo correcto; `git-reader` (`submodulos`) confirma el puntero de la raíz. Corregir lo que falte solo agregando, nunca reescribiendo; si algo no se puede, reportarlo.

## Salida
Reporte corto con una fila por PR: repositorio, versión y tag, enlace de la release, y el tag de la raíz si correspondió. Después: PR de devolución a otras ramas (número y enlace, o pendientes), y los issues comentados. Veredicto:
- **FIX TAGUEADO:** tag y release creados (y raíz, si correspondía).
- **PARCIAL:** qué se hizo y qué quedó pendiente, con el motivo.
- **NO PROCEDE:** el PR no cumple los pre-chequeos.
