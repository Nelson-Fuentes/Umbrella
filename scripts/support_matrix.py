#!/usr/bin/env python3
"""Genera docs/soporte-por-agente.md a partir de la tabla de soporte que el propio
rulesync instalado reporta (rulesync docs reference/supported-tools), no de memoria.

Para cada agente soportado por rulesync y cada feature que la metodologia usa
(skills, subagentes, reglas, hooks), marca:
  - "si"        si la columna del tool en la tabla de rulesync trae ese feature
  - "degradado" si la trae solo en forma simulada (simulated-*)
  - "no"        si el tool no soporta el feature (se omite, no falla la build)

Las columnas "restriccion de herramientas" y "modelo" dependen del contenido de
cada subagente ya generado, archivo por archivo, por tool; verificarlas una por
una excede esta pasada automatica, asi que quedan marcadas [VERIFICAR].
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RULESYNC_BIN = ROOT / "node_modules" / ".bin" / "rulesync"

FEATURES = ["rules", "subagents", "skills", "hooks"]
FEATURE_LABEL = {
    "rules": "Reglas",
    "subagents": "Subagentes",
    "skills": "Skills",
    "hooks": "Hooks",
}
COL_INDEX = {
    # indice de columna (0-based, tras separar por '|' y quitar bordes) en la
    # tabla de reference/supported-tools para cada feature que nos interesa.
    "rules": 2,
    "subagents": 6,
    "skills": 7,
    "hooks": 8,
}


def run_docs() -> str:
    import os

    bin_path = os.environ.get("RULESYNC", str(RULESYNC_BIN))
    if not Path(bin_path).exists():
        print(f"error: no se encontro el binario de rulesync en {bin_path}", file=sys.stderr)
        sys.exit(1)
    result = subprocess.run(
        [bin_path, "docs", "reference/supported-tools"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout


def parse_table(doc_text: str):
    rows = []
    in_table = False
    for line in doc_text.splitlines():
        if line.startswith("| Tool"):
            in_table = True
            continue
        if in_table and line.startswith("| ---"):
            continue
        if in_table and line.startswith("|"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) < 9:
                continue
            tool_name = re.sub(r"\s*[⚠️]+\s*$", "", cells[0]).strip()
            target_key = cells[1].strip()
            if not target_key or target_key == "--targets":
                continue
            rows.append((tool_name, target_key, cells))
        elif in_table and not line.startswith("|"):
            break
    return rows


def cell_state(cell: str) -> str:
    if "✅" in cell:
        return "si"
    if "🎮" in cell:
        return "degradado (simulado)"
    return "no"


def main() -> int:
    doc_text = run_docs()
    rows = parse_table(doc_text)
    if not rows:
        print("error: no se pudo parsear la tabla de reference/supported-tools", file=sys.stderr)
        return 1

    out_lines = [
        "# Soporte por agente",
        "",
        "Generado por `scripts/support_matrix.py` a partir de la tabla de capacidades",
        "que el rulesync instalado (version fijada en `package.json`) reporta con",
        "`rulesync docs reference/supported-tools`. No es una lista de memoria: si una",
        "version nueva de rulesync agrega o quita un target, esta tabla cambia solo",
        "con volver a correr `./build.sh`.",
        "",
        "`restriccion de herramientas` y `modelo` dependen del contenido final de cada",
        "subagente generado, archivo por archivo, por target; esta pasada automatica",
        "no los verifica uno por uno y los marca `[VERIFICAR]`.",
        "",
        "| Agente (--targets) | Skills | Subagentes | Reglas | Hooks | Restriccion de herramientas | Modelo |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]

    for tool_name, target_key, cells in rows:
        skills = cell_state(cells[COL_INDEX["skills"]])
        subagents = cell_state(cells[COL_INDEX["subagents"]])
        rules = cell_state(cells[COL_INDEX["rules"]])
        hooks = cell_state(cells[COL_INDEX["hooks"]])
        out_lines.append(
            f"| {tool_name} (`{target_key}`) | {skills} | {subagents} | {rules} | {hooks} | [VERIFICAR] | [VERIFICAR] |"
        )

    out_dir = ROOT / "docs"
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "soporte-por-agente.md").write_text("\n".join(out_lines) + "\n")
    print(f"Escrito {out_dir / 'soporte-por-agente.md'} ({len(rows)} agentes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
