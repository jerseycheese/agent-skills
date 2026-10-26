#!/usr/bin/env python3
"""Lint skills/*/SKILL.md frontmatter and the indexes that list each skill.

Stdlib only, so CI needs no installs. The frontmatter parser covers the YAML
subset these files use: top-level `key: value`, quoted scalars, and `>` / `|`
block scalars.
"""
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILLS = ROOT / "skills"
MAX_DESCRIPTION = 400

errors = []


def fail(skill, msg):
    errors.append(f"{skill}: {msg}")


def strip_comment(s):
    return re.sub(r"(^|\s)#.*$", "", s).strip()


def parse_frontmatter(text):
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        raise ValueError("no opening --- on line 1")
    try:
        end = lines.index("---", 1)
    except ValueError:
        raise ValueError("no closing ---")

    fields = {}
    body = lines[1:end]
    i = 0
    while i < len(body):
        line = body[i]
        if not line.strip() or line.lstrip().startswith("#"):
            i += 1
            continue
        m = re.match(r"^([A-Za-z0-9_-]+):(?:\s+(.*))?$", line)
        if not m:
            raise ValueError(f"can't parse line: {line!r}")
        key, value = m.group(1), (m.group(2) or "").strip()
        i += 1
        cont = []
        while i < len(body) and (not body[i].strip() or body[i].startswith((" ", "\t"))):
            cont.append(body[i].strip())
            i += 1
        while cont and not cont[-1]:
            cont.pop()

        # YAML drops a " #..." comment after a plain scalar or block indicator.
        if value[:1] not in ('"', "'"):
            value = strip_comment(value)

        if value[:1] in (">", "|"):
            if value.lstrip(">|+-0123456789"):
                raise ValueError(f"{key}: unexpected text after block indicator")
            sep = " " if value[0] == ">" else "\n"
            value = sep.join(cont)
        elif value[:1] in ('"', "'"):
            q = value[0]
            value = " ".join([value] + cont)
            if len(value) < 2 or value[-1] != q:
                raise ValueError(f"{key}: unterminated {q}-quoted string")
            value = value[1:-1]
        elif cont:
            value = " ".join([value] + [strip_comment(c) for c in cont])
        fields[key] = value.strip()
    return fields


def main():
    skill_dirs = sorted(p for p in SKILLS.iterdir() if p.is_dir())
    names = {p.name for p in skill_dirs}

    market = json.loads((ROOT / ".claude-plugin" / "marketplace.json").read_text())
    listed = {
        os.path.normpath(s)
        for plugin in market.get("plugins", [])
        for s in plugin.get("skills", [])
    }
    readme = (ROOT / "README.md").read_text()

    for d in skill_dirs:
        name = d.name
        skill_md = d / "SKILL.md"
        if not skill_md.is_file():
            fail(name, "missing SKILL.md")
            continue
        try:
            fm = parse_frontmatter(skill_md.read_text())
        except ValueError as e:
            fail(name, f"frontmatter doesn't parse: {e}")
            fm = None

        if fm is not None:
            if fm.get("name") != name:
                fail(name, f"name {fm.get('name')!r} doesn't match folder name")
            desc = fm.get("description", "")
            if not desc:
                fail(name, "missing description")
            elif len(desc) > MAX_DESCRIPTION:
                fail(name, f"description is {len(desc)} chars (max {MAX_DESCRIPTION})")

        if f"skills/{name}" not in listed:
            fail(name, "not listed in .claude-plugin/marketplace.json")
        if f"(skills/{name}/SKILL.md)" not in readme:
            fail(name, "not linked from README.md")

        for f in sorted(d.rglob("*")):
            if not f.is_file():
                continue
            try:
                text = f.read_text()
            except UnicodeDecodeError:
                continue
            for n, line in enumerate(text.split("\n"), 1):
                if "/Users/" in line:
                    fail(name, f"absolute /Users/ path at {f.relative_to(ROOT)}:{n}")
                if ".local.md" in line:
                    fail(name, f"private .local.md reference at {f.relative_to(ROOT)}:{n}")

    for stale in sorted(listed - {f"skills/{n}" for n in names}):
        fail(stale, "listed in marketplace.json but isn't a skills/ folder")

    if errors:
        print("\n".join(errors))
        print(f"\n{len(errors)} problem(s) across {len(skill_dirs)} skills")
        return 1
    print(f"OK: {len(skill_dirs)} skills")
    return 0


if __name__ == "__main__":
    sys.exit(main())
