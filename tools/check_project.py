#!/usr/bin/env python3
"""Check release files and the write/replace operations Godot needs. Standard library only.

python tools/check_project.py
python tools/check_project.py --root /path/to/extracted/project
python tools/check_project.py --generate  # maintainer: refresh manifest after edits

This reports differences; it NEVER overwrites game files or changes security settings.
The manifest detects accidental corruption/incomplete extraction, not malicious tampering.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = "integrity.json"
TOP_FILES = (".gitattributes", ".gitignore", "CHECK_PROJECT.cmd", "LICENSE", "README.md",
             "START_HERE.txt", "project.godot", "export_presets.cfg", "icon.svg")
FOLDERS = ("scenes", "scripts", "shaders", "assets", "docs", "tests", "tools")
OPTIONAL_MUSIC = {"assets/music/breakcore.ogg", "assets/music/breakcore.mp3"}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe_path(root: Path, name: str) -> Path:
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()) or path == root.resolve():
        raise ValueError(f"Unsafe manifest path: {name}")
    return path


def generate(root: Path) -> None:
    files = [root / f for f in TOP_FILES]
    for folder in FOLDERS:
        files.extend(p for p in (root / folder).rglob("*") if p.is_file()
                     and "__pycache__" not in p.parts
                     and p.suffix not in {".pyc", ".uid", ".import"}
                     and p.relative_to(root).as_posix() not in OPTIONAL_MUSIC)
    entries = {p.relative_to(root).as_posix(): digest(p) for p in sorted(set(files))}
    data = {"format": 1, "version": "0.2.1", "algorithm": "SHA-256", "files": entries}
    (root / MANIFEST).write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Manifest generated: {len(entries)} files")


def check_files(root: Path) -> list[str]:
    problems = []
    try:
        data = json.loads((root / MANIFEST).read_text(encoding="utf-8"))
        if data.get("format") != 1 or data.get("algorithm") != "SHA-256" or not data.get("files"):
            raise ValueError("Unsupported or empty integrity manifest")
        for name, expected in data["files"].items():
            try:
                path = safe_path(root, name)
                if not path.is_file():
                    problems.append(f"MISSING: {name}")
                elif digest(path) != expected:
                    problems.append(f"CHANGED: {name}")
            except (OSError, ValueError) as error:
                problems.append(f"UNREADABLE: {name}: {error}")
    except (OSError, ValueError, TypeError, AttributeError) as error:
        problems.append(f"MANIFEST: {error}")
    return problems


def check_resources(root: Path) -> list[str]:
    problems = []
    project = root / "project.godot"
    try:
        text = project.read_text(encoding="utf-8-sig")
        match = re.search(r'^run/main_scene="res://([^"\n]+)"', text, re.MULTILINE)
        if not match:
            return ["MAIN SCENE: missing run/main_scene setting"]
        scene = safe_path(root, match[1])
        if not scene.is_file():
            problems.append(f"MAIN SCENE MISSING: {match[1]}")
        elif not scene.read_text(encoding="utf-8-sig").lstrip().startswith("[gd_scene "):
            problems.append(f"INVALID SCENE HEADER: {match[1]}")
        sources = [project] + list((root / "scripts").glob("*.gd")) + list((root / "scenes").glob("*.tscn"))
        for source in sources:
            for name in re.findall(r'"res://([^"\n]+)"', source.read_text(encoding="utf-8-sig")):
                if name in OPTIONAL_MUSIC:
                    continue
                target = safe_path(root, name)
                if not target.is_file():
                    problems.append(f"BROKEN REFERENCE: {source.relative_to(root)} -> {name}")
    except (OSError, ValueError, UnicodeError) as error:
        problems.append(f"RESOURCE CHECK: {error}")
    return problems


def probe_directory(folder: Path) -> str | None:
    """Use a private subdirectory and os.replace, never an actual project file."""
    try:
        with tempfile.TemporaryDirectory(prefix=".rift-write-test-", dir=folder) as temp:
            old, new = Path(temp) / "original", Path(temp) / "replacement"
            old.write_bytes(b"before")
            new.write_bytes(b"after")
            os.replace(new, old)
            if old.read_bytes() != b"after":
                raise OSError("Replacement contents could not be read back")
    except OSError as error:
        return f"WRITE/REPLACE FAILED: {folder}: {error}"
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--generate", action="store_true")
    parser.add_argument("--no-write-probe", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    if args.generate:
        generate(root)
        return 0
    print(f"RIFT RUSH 0.2.1 — integrity check\nProject: {root}")
    problems = check_files(root) + check_resources(root)
    if not args.no_write_probe:
        folders = [root, root / "scenes"]
        if (root / ".godot").exists():
            folders.append(root / ".godot")
        for folder in folders:
            error = probe_directory(folder)
            if error:
                problems.append(error)
    for problem in problems:
        print(problem)
    if problems:
        print("FAIL: extract the COMPLETE fresh ZIP into a new writable folder.")
        print("CHANGED can also mean an intentional edit, not necessarily corruption.")
        return 1
    print("PASS: all release files and local resource references match.")
    if not args.no_write_probe:
        print("PASS: temporary files can be created, replaced and removed.")
    print("This does not test Godot's own antivirus permissions or parse GDScript.")
    print(f"Import this exact file in Godot: {root / 'project.godot'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
