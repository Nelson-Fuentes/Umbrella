#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

PLUGIN_NAME="umbrella"
RULESYNC_BIN="${RULESYNC:-node_modules/.bin/rulesync}"

if [ ! -x "$RULESYNC_BIN" ]; then
  echo "error: no se encontro $RULESYNC_BIN. Ejecuta 'npm ci' primero (o exporta RULESYNC=<ruta-al-binario>)." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: se requiere python3 en el PATH." >&2
  exit 1
fi

run_rulesync() {
  "$RULESYNC_BIN" generate "$@"
}

echo "==> Limpiando dist/"
rm -rf dist
mkdir -p dist/project "dist/claude/plugins/${PLUGIN_NAME}" "dist/antigravity/${PLUGIN_NAME}"

echo "==> Generando dist/project (todos los targets y features)"
run_rulesync --targets '*' --features '*' --output-roots ./dist/project

echo "==> Generando el plugin de Claude Code en dist/claude/plugins/${PLUGIN_NAME}"
run_rulesync \
  --targets claudecode-plugin \
  --features mcp,commands,subagents,skills,hooks \
  --output-roots "./dist/claude/plugins/${PLUGIN_NAME}"

echo "==> Generando el plugin de Antigravity en dist/antigravity/${PLUGIN_NAME}"
run_rulesync \
  --targets antigravity-plugin \
  --features rules,mcp,subagents,skills,hooks \
  --output-roots "./dist/antigravity/${PLUGIN_NAME}"

echo "==> Copiando manifiestos de packaging/ y la regla de runtime que el formato de plugin no incluye"
cp -r "packaging/claudecode-plugin/.claude-plugin" "dist/claude/plugins/${PLUGIN_NAME}/"
mkdir -p "dist/claude/.claude-plugin"
cp "packaging/claudecode-marketplace/.claude-plugin/marketplace.json" "dist/claude/.claude-plugin/marketplace.json"
mkdir -p "dist/claude/plugins/${PLUGIN_NAME}/docs/rules"
cp ".rulesync/rules/sdd-antigravity-runtime.md" "dist/claude/plugins/${PLUGIN_NAME}/docs/rules/"
cp ".rulesync/rules/sdd-metodologia-umbrella.md" "dist/claude/plugins/${PLUGIN_NAME}/docs/rules/"

# antigravity-plugin: rulesync solo crea plugin.json cuando falta; el manifiesto
# de packaging/ trae name/description definitivos, asi que se copia siempre.
cp "packaging/antigravity-plugin/plugin.json" "dist/antigravity/${PLUGIN_NAME}/plugin.json"

echo "==> Generando docs/soporte-por-agente.md"
python3 scripts/support_matrix.py

echo "==> Validando"
python3 scripts/validate.py

echo
echo "==> Resumen de la build"
echo "  dist/project/              -> salida de proyecto para todos los targets soportados"
echo "  dist/claude/plugins/${PLUGIN_NAME}/  -> plugin claudecode-plugin (mcp,commands,subagents,skills,hooks)"
echo "  dist/antigravity/${PLUGIN_NAME}/     -> plugin antigravity-plugin (rules,mcp,subagents,skills,hooks)"
echo "  docs/soporte-por-agente.md -> tabla agente x feature derivada de lo generado"
