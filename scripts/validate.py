#!/usr/bin/env python3
"""Valida que la build haya producido lo esperado. Falla (exit != 0) si falta algo."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"
PLUGIN_NAME = "umbrella"

errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def main() -> int:
    project = DIST / "project"
    require(project.is_dir(), f"falta {project}")

    claude_plugin = DIST / "claude" / "plugins" / PLUGIN_NAME
    require(claude_plugin.is_dir(), f"falta {claude_plugin}")
    claude_manifest = claude_plugin / ".claude-plugin" / "plugin.json"
    require(claude_manifest.is_file(), f"falta {claude_manifest}")
    if claude_manifest.is_file():
        try:
            data = json.loads(claude_manifest.read_text())
            require("name" in data, f"{claude_manifest} sin 'name'")
        except json.JSONDecodeError as exc:
            errors.append(f"{claude_manifest} no es JSON valido: {exc}")
    require(
        (claude_plugin / "agents").is_dir(),
        f"faltan subagentes en {claude_plugin / 'agents'}",
    )
    require(
        (claude_plugin / "skills").is_dir(),
        f"faltan skills en {claude_plugin / 'skills'}",
    )
    require(
        (claude_plugin / "docs" / "rules" / "sdd-antigravity-runtime.md").is_file(),
        "no se copio la regla de runtime al plugin de Claude Code (claudecode-plugin no genera 'rules')",
    )

    claude_marketplace = DIST / "claude" / ".claude-plugin" / "marketplace.json"
    require(claude_marketplace.is_file(), f"falta {claude_marketplace}")
    if claude_marketplace.is_file():
        try:
            data = json.loads(claude_marketplace.read_text())
            names = [p.get("name") for p in data.get("plugins", [])]
            require(
                PLUGIN_NAME in names,
                f"{claude_marketplace} no lista el plugin '{PLUGIN_NAME}'",
            )
        except json.JSONDecodeError as exc:
            errors.append(f"{claude_marketplace} no es JSON valido: {exc}")

    antigravity_plugin = DIST / "antigravity" / PLUGIN_NAME
    require(antigravity_plugin.is_dir(), f"falta {antigravity_plugin}")
    ag_manifest = antigravity_plugin / "plugin.json"
    require(ag_manifest.is_file(), f"falta {ag_manifest}")
    if ag_manifest.is_file():
        try:
            data = json.loads(ag_manifest.read_text())
            require("name" in data, f"{ag_manifest} sin 'name'")
        except json.JSONDecodeError as exc:
            errors.append(f"{ag_manifest} no es JSON valido: {exc}")
    require(
        (antigravity_plugin / "rules").is_dir(),
        f"faltan reglas en {antigravity_plugin / 'rules'}",
    )
    require(
        (antigravity_plugin / "agents").is_dir(),
        f"faltan subagentes en {antigravity_plugin / 'agents'}",
    )
    require(
        (antigravity_plugin / "skills").is_dir(),
        f"faltan skills en {antigravity_plugin / 'skills'}",
    )

    support_doc = ROOT / "docs" / "soporte-por-agente.md"
    require(support_doc.is_file(), f"falta {support_doc} (ejecuta scripts/support_matrix.py)")

    rulesync_subagents = list((ROOT / ".rulesync" / "subagents").glob("*.md"))
    rulesync_skills = list((ROOT / ".rulesync" / "skills").glob("*/SKILL.md"))
    require(len(rulesync_subagents) > 0, "no hay subagentes fuente en .rulesync/subagents/")
    require(len(rulesync_skills) > 0, "no hay skills fuente en .rulesync/skills/")

    if errors:
        print("VALIDACION FALLIDA:")
        for e in errors:
            print(f"  - {e}")
        return 1

    print("OK: validacion de la build pasada.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
