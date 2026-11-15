---
name: sdd-cleanup
description: "Limpia y corrige ramas residuales o anómalas en los submódulos y la raíz dejadas por versiones anteriores del plugin o ejecuciones erróneas: audita ramas locales y remotas en los repositorios, detecta ramas de especificación o huérfanas en submódulos de código, presenta la tabla de hallazgos al usuario para su confirmación y elimina de forma segura las ramas locales y remotas seleccionadas con sdd-git-operator, asegurando que los submódulos queden en su rama base limpia."
---

# sdd-cleanup

> **Antigravity:** los subagentes se invocan con `invoke_subagent`; equivalencias de herramientas, `CLAUDE.md`/`AGENTS.md` y `/speckit.*` según la regla `sdd-antigravity-runtime` del plugin.

Audita, detecta y elimina de forma controlada y segura ramas residuales, huérfanas o indebidas (locales y remotas en GitHub) creadas por versiones antiguas del plugin o flujos previos (por ejemplo, ramas `usr-*`, `rfr-*`, `hfr-*` o `feature/*` que se hayan creado indebidamente en los submódulos de código).

## Delegación
El contexto principal no ejecuta `git`, `gh` ni el MCP de GitHub:
- `sdd-git-reader`: audita y lista las ramas locales y remotas de los submódulos y la raíz.
- `sdd-git-operator`: checkout a ramas base y eliminación segura de ramas locales y remotas autorizadas.

## Reglas Inviolables
1. **PROTECCIÓN TOTAL DE RAMAS BASE:** Está terminantemente PROHIBIDO eliminar ramas base o de producción (`main`, `master`, `develop`, `release`).
2. **CONFIRMACIÓN PREVIA EXPLÍCITA:** Ninguna rama local ni remota se elimina sin que el usuario haya visto la lista y dado su confirmación expresa en el chat.
3. **SALVAGUARDA DE RAMA ACTIVA:** Si un submódulo está actualmente situado sobre una rama a eliminar, antes de borrar la rama local se debe hacer checkout hacia su rama base (`develop`, `release` o `main`).

## Entradas (preguntar si faltan, nunca asumir)
- **Alcance de repositorios:** todos los submódulos de código (por defecto) o un submódulo específico indicado por el usuario.
- **Tipo de limpieza:**
  - `anómalas` (por defecto): ramas de especificación (`usr-*`, `rfr-*`, `hfr-*`, `feature/*`) que nunca debieron existir en los submódulos de código.
  - `fusionadas`: ramas de tareas (`*-tk-*`) cuyos PRs ya han sido fusionados a la rama base.
  - `todas`: anómalas + fusionadas.
- **Eliminar remotas:** `sí` (por defecto) o solo locales.

## Pasos (en orden)

### 1. Auditoría de ramas
Con `sdd-git-reader`:
- `estado-repos`: verificar que no existan cambios de código sin commitear en los submódulos. Si hay cambios pendientes no SDD, detenerse y reportar como bloqueo.
- `listar-ramas` en cada submódulo de código: obtener todas las ramas locales y remotas (`origin/*`).
- Identificar ramas residuales o anómalas:
  - En **submódulos de código**: cualquier rama que siga el patrón de especificación (`usr-*`, `rfr-*`, `hfr-*`, `feature/*`). En la metodología SDD Umbrella, estas ramas solo pertenecen al repo raíz de especificaciones.
  - Ramas de tareas (`*-tk-*`) cuyo PR asociado ya esté cerrado o fusionado (comprobar con `pr`).

### 2. Presentación del plan de limpieza
Mostrar al usuario una tabla clara con los hallazgos:

| Submódulo | Rama | Ubicación | Motivo | Estado del Repo | Acción propuesta |
|---|---|---|---|---|---|
| B1Route-Backend | usr-001-login | Local y Remota | Rama de spec en submódulo (antigua) | Rama activa (requiere checkout a develop) | Checkout a develop y eliminar local + remota |
| B1Route-Frontend | rfr-002-fix | Solo Remota | Rama de spec en submódulo (antigua) | En develop | Eliminar remota |

Preguntar al usuario:
1. ¿Confirmas la eliminación de estas ramas? (o indicar cuáles excluir).
2. ¿Confirmas eliminar tanto la versión local como la remota en GitHub?

### 3. Ejecución segura (en una sola invocación agrupada a git-operator)
Con confirmación del usuario, invocar a `sdd-git-operator` en **UNA SOLA INVOCACIÓN** encadenada para todos los submódulos autorizados:
1. **Checkout a rama base (si aplica):** para los submódulos que se encuentren posicionados sobre una rama a eliminar, cambiarlos primero a su rama base (`develop`, `release` o `main`).
2. **Eliminar ramas:** ejecutar la lista completa de eliminaciones de ramas locales y remotas confirmadas para cada submódulo.

### 4. Verificación final
Con `sdd-git-reader`:
- `listar-ramas` en los submódulos intervenidos: verificar que las ramas eliminadas ya no figuren ni en local ni en remoto (`origin/`).
- `estado-repos`: verificar que cada submódulo haya quedado posicionado en su rama base correspondiente y con árbol de trabajo limpio.

## Salida
Reporte estructurado con:
- Submódulos auditados.
- Ramas eliminadas (locales y remotas).
- Estado final de cada submódulo (rama activa y estado limpio).
- Confirmación de que las ramas base (`develop`, `release`, `main`/`master`) permanecen intactas.
