#!/usr/bin/env bash
# Instala la build de este repo en los agentes detectados en esta maquina.
# Claude Code se instala como plugin real (marketplace local + `claude plugin
# install`); el resto de agentes, copiando dist/project/ a su carpeta de
# configuracion. No sobrescribe nada sin confirmacion explicita del usuario.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="${SCRIPT_DIR}/dist/project"
CLAUDE_MARKETPLACE_DIR="${SCRIPT_DIR}/dist/claude"
CLAUDE_MARKETPLACE_NAME="umbrella-local"
CLAUDE_PLUGIN_ID="umbrella@${CLAUDE_MARKETPLACE_NAME}"
# Scope "user": se copia a una ruta estable fuera del repo, para que el
# plugin siga funcionando aunque esta carpeta se mueva o se borre despues.
CLAUDE_STABLE_DIR="${HOME}/.local/share/umbrella-sdd/claude-plugin"
TARGET_DIR="${1:-$(pwd)}"

if [ ! -d "$DIST" ]; then
  echo "error: no existe $DIST. Ejecuta ./build.sh primero." >&2
  exit 1
fi

# tool_key -> "marcador_de_deteccion|ruta_origen_en_dist|ruta_destino"
# La ruta destino es relativa a TARGET_DIR salvo que empiece con '~', que se
# resuelve contra HOME (instalacion global del agente).
# El marcador puede llevar varias rutas separadas por ',': se detecta si
# CUALQUIERA de ellas existe (por ejemplo, config de proyecto o global).
# Claude Code no esta aqui: se instala como plugin (ver install_claudecode_plugin).
CANDIDATES=(
  "cursor|.cursor|.cursor/rules;.cursor/agents;.cursor/skills|.cursor"
  "antigravity|.agents|.agents/rules;.agents/agents;.agents/skills|.agents"
  "antigravity-global|~/.gemini|.agents/rules;.agents/agents;.agents/skills|~/.gemini/config"
  "copilot|.github|.github/instructions|.github/instructions"
  "codexcli|AGENTS.md| |"
  "opencode|.opencode|.opencode/memories|.opencode"
)

detect_marker() {
  local markers="$1"
  local marker
  IFS=',' read -r -a marker_list <<<"$markers"
  for marker in "${marker_list[@]}"; do
    if [[ "$marker" == ~* ]]; then
      marker="${marker/#\~/$HOME}"
    else
      marker="${TARGET_DIR}/${marker}"
    fi
    [ -e "$marker" ] && return 0
  done
  return 1
}

install_claudecode_plugin() {
  local scope="$1"
  if ! command -v claude >/dev/null 2>&1; then
    echo "  error: no se encontro el comando 'claude' en el PATH. Instala Claude Code o agrega el binario al PATH y reintenta." >&2
    return 1
  fi

  local marketplace_src="$CLAUDE_MARKETPLACE_DIR"
  if [ "$scope" = "user" ]; then
    echo "  copiando ${CLAUDE_MARKETPLACE_DIR} -> ${CLAUDE_STABLE_DIR} (copia estable fuera del repo)"
    rm -rf "$CLAUDE_STABLE_DIR"
    mkdir -p "$CLAUDE_STABLE_DIR"
    cp -r "${CLAUDE_MARKETPLACE_DIR}/." "${CLAUDE_STABLE_DIR}/"
    marketplace_src="$CLAUDE_STABLE_DIR"
    # Si ya estaba registrado apuntando a otra ruta (p.ej. el repo), hay que
    # quitarlo antes: 'marketplace add' no reubica un nombre existente.
    claude plugin marketplace remove "$CLAUDE_MARKETPLACE_NAME" --scope "$scope" >/dev/null 2>&1 || true
  fi

  echo "  claude plugin marketplace add ${marketplace_src} --scope ${scope}"
  claude plugin marketplace add "$marketplace_src" --scope "$scope"
  echo "  claude plugin install ${CLAUDE_PLUGIN_ID} --scope ${scope}"
  claude plugin install "$CLAUDE_PLUGIN_ID" --scope "$scope"
}

echo "Buscando agentes instalados en ${TARGET_DIR} y en \$HOME..."
DETECTED_KEYS=()
DETECTED_LABELS=()
i=1

if command -v claude >/dev/null 2>&1; then
  DETECTED_KEYS+=("claudecode")
  DETECTED_LABELS+=("$i) claudecode  (plugin de proyecto via 'claude plugin install', scope project)")
  i=$((i + 1))
  DETECTED_KEYS+=("claudecode-global")
  DETECTED_LABELS+=("$i) claudecode-global  (plugin de usuario, copia estable fuera del repo, scope user)")
  i=$((i + 1))
fi

for entry in "${CANDIDATES[@]}"; do
  IFS='|' read -r key marker _srcs _dst <<<"$entry"
  if detect_marker "$marker"; then
    DETECTED_KEYS+=("$key")
    DETECTED_LABELS+=("$i) $key  (detectado via $marker)")
    i=$((i + 1))
  fi
done

if [ ${#DETECTED_KEYS[@]} -eq 0 ]; then
  echo "No se detecto ningun agente conocido en ${TARGET_DIR} ni en \$HOME."
  echo "Instala manualmente desde dist/project/ o crea el directorio del agente antes de reintentar."
  exit 0
fi

echo
echo "Agentes detectados:"
printf '%s\n' "${DETECTED_LABELS[@]}"
echo "Escribe los numeros a instalar separados por espacio (o 'todos'):"
read -r SELECTION

SELECTED_KEYS=()
if [ "$SELECTION" = "todos" ]; then
  SELECTED_KEYS=("${DETECTED_KEYS[@]}")
else
  for n in $SELECTION; do
    idx=$((n - 1))
    if [ "$idx" -ge 0 ] && [ "$idx" -lt ${#DETECTED_KEYS[@]} ]; then
      SELECTED_KEYS+=("${DETECTED_KEYS[$idx]}")
    fi
  done
fi

for key in "${SELECTED_KEYS[@]}"; do
  case "$key" in
    claudecode)
      install_claudecode_plugin project
      continue
      ;;
    claudecode-global)
      install_claudecode_plugin user
      continue
      ;;
  esac

  for entry in "${CANDIDATES[@]}"; do
    IFS='|' read -r ckey _marker srcs dst <<<"$entry"
    [ "$ckey" = "$key" ] || continue
    dst_resolved="$dst"
    if [[ "$dst_resolved" == ~* ]]; then
      dst_resolved="${dst_resolved/#\~/$HOME}"
    else
      dst_resolved="${TARGET_DIR}/${dst_resolved}"
    fi
    IFS=';' read -r -a src_list <<<"$srcs"
    for src in "${src_list[@]}"; do
      src=$(echo "$src" | xargs)
      [ -z "$src" ] && continue
      src_path="${DIST}/${src}"
      [ -e "$src_path" ] || continue
      base_name="$(basename "$src")"
      dest_path="${dst_resolved}"
      mkdir -p "$(dirname "$dest_path")"
      if [ -e "$dest_path/$base_name" ]; then
        read -r -p "  ${dest_path}/${base_name} ya existe. Sobrescribir? [s/N] " ans
        [[ "$ans" =~ ^[sS]$ ]] || { echo "  omitido: $dest_path/$base_name"; continue; }
      fi
      mkdir -p "$dest_path"
      cp -r "$src_path" "$dest_path/"
      echo "  copiado: $src -> $dest_path/$base_name"
    done
  done
done

echo "Listo. Reinicia la sesion del agente para que recargue las skills/subagentes/plugins."
