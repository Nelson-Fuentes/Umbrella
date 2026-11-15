#!/usr/bin/env python3
"""One-off conversion of vendor/antigravity-plugin-source/* into .rulesync/ canonical
sources. Run manually when the vendored Antigravity plugin is updated; not part of
the build pipeline (build.sh only runs rulesync against the already-converted
.rulesync/ tree)."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "vendor" / "antigravity-plugin-source"
DST = ROOT / ".rulesync"


def split_frontmatter(text: str) -> tuple[dict, str]:
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    if not m:
        raise ValueError("no frontmatter")
    raw_fm, body = m.group(1), m.group(2)
    fm: dict = {}
    key = None
    for line in raw_fm.splitlines():
        if re.match(r"^[A-Za-z_]+:", line):
            key, _, val = line.partition(":")
            val = val.strip()
            if val == "":
                fm[key] = []
            elif val.startswith('"') and val.endswith('"'):
                fm[key] = val[1:-1]
            else:
                fm[key] = val
        elif line.strip().startswith("- ") and key is not None and isinstance(fm.get(key), list):
            fm[key].append(line.strip()[2:])
    return fm, body


def yaml_str(s: str) -> str:
    s = s.replace('"', '\\"')
    return f'"{s}"'


def convert_rules():
    out = DST / "rules"
    out.mkdir(parents=True, exist_ok=True)
    for f in sorted((SRC / "rules").glob("*.md")):
        fm, body = split_frontmatter(f.read_text())
        trigger = fm["trigger"]
        desc = fm["description"]
        lines = [
            "---",
            "root: false",
            'targets: ["*"]',
            f"description: {yaml_str(desc)}",
            'globs: ["**/*"]',
            "antigravity:",
            f"  trigger: {trigger}",
        ]
        if trigger == "model_decision":
            lines.append(f"  description: {yaml_str(desc)}")
        lines += ["---", "", body.strip(), ""]
        (out / f.name).write_text("\n".join(lines))
        print(f"rule -> {out / f.name}")


def convert_subagents():
    out = DST / "subagents"
    out.mkdir(parents=True, exist_ok=True)
    for f in sorted((SRC / "agents").glob("*.md")):
        fm, body = split_frontmatter(f.read_text())
        name = fm["name"]
        desc = fm["description"]
        tools = fm.get("tools", [])
        model = fm.get("model", "inherit")
        policy = fm.get("commandExecutionPolicy", "off")
        lines = [
            "---",
            f"name: {name}",
            'targets: ["*"]',
            f"description: {yaml_str(desc)}",
            "antigravity:",
            "  tools:",
        ]
        for t in tools:
            lines.append(f"    - {t}")
        lines += [
            "  mainAgent: false",
            "  subagent: true",
            f"  model: {model}",
            f"  commandExecutionPolicy: {yaml_str(policy) if policy == 'off' else policy}",
            "claudecode:",
            f"  model: {'haiku' if model == 'flash' else 'inherit'}",
        ]
        if policy == "off":
            lines.append('  disallowedTools: ["Bash"]')
        lines += ["---", "", body.strip(), ""]
        (out / f.name).write_text("\n".join(lines))
        print(f"subagent -> {out / f.name}")


def convert_skills():
    out = DST / "skills"
    out.mkdir(parents=True, exist_ok=True)
    for d in sorted((SRC / "skills").glob("*")):
        skill_md = d / "SKILL.md"
        if not skill_md.exists():
            continue
        fm, body = split_frontmatter(skill_md.read_text())
        name = fm["name"]
        desc = fm["description"]
        lines = [
            "---",
            f"name: {name}",
            'targets: ["*"]',
            f"description: {yaml_str(desc)}",
            "---",
            "",
            body.strip(),
            "",
        ]
        dest_dir = out / name
        dest_dir.mkdir(parents=True, exist_ok=True)
        (dest_dir / "SKILL.md").write_text("\n".join(lines))
        print(f"skill -> {dest_dir / 'SKILL.md'}")


if __name__ == "__main__":
    convert_rules()
    convert_subagents()
    convert_skills()
