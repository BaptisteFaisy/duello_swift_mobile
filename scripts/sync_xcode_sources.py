#!/usr/bin/env python3
"""Synchronise `Duello.xcodeproj/project.pbxproj` avec le dossier `Duello/`.

Le projet Xcode de Duello liste explicitement chaque fichier source (pas de
groupe synchronisé du système de fichiers). Ajouter un `.swift` à la main dans
les quatre sections du pbxproj est fastidieux et source d'erreurs ; ce script
le fait de façon déterministe et idempotente :

- PBXBuildFile      (l'entrée de compilation)
- PBXFileReference  (la référence de fichier)
- PBXGroup « Duello » (l'arborescence)
- PBXSourcesBuildPhase (la phase de compilation)

Usage : `python3 scripts/sync_xcode_sources.py`
"""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PBX = ROOT / "Duello.xcodeproj" / "project.pbxproj"
SRC_DIR = ROOT / "Duello"


def stable_id(name: str, kind: str) -> str:
    """Identifiant 24 caractères hexadécimaux, dérivé du nom (déterministe)."""
    digest = hashlib.sha1(f"{kind}:{name}".encode("utf-8")).hexdigest().upper()
    return digest[:24]


def main() -> int:
    if not PBX.exists():
        print(f"pbxproj introuvable : {PBX}", file=sys.stderr)
        return 1

    text = PBX.read_text(encoding="utf-8")
    swift_files = sorted(p.name for p in SRC_DIR.glob("*.swift"))
    missing = [name for name in swift_files if f"/* {name} */" not in text]

    if not missing:
        print(f"Rien à ajouter : {len(swift_files)} fichiers .swift déjà référencés.")
        return 0

    build_block = "".join(
        f"\t\t{stable_id(n, 'build')} /* {n} in Sources */ = "
        f"{{isa = PBXBuildFile; fileRef = {stable_id(n, 'ref')} /* {n} */; }};\n"
        for n in missing
    )
    ref_block = "".join(
        f"\t\t{stable_id(n, 'ref')} /* {n} */ = {{isa = PBXFileReference; "
        f'lastKnownFileType = sourcecode.swift; path = {n}; sourceTree = "<group>"; }};\n'
        for n in missing
    )
    children_block = "".join(
        f"\t\t\t\t{stable_id(n, 'ref')} /* {n} */,\n" for n in missing
    )
    sources_block = "".join(
        f"\t\t\t\t{stable_id(n, 'build')} /* {n} in Sources */,\n" for n in missing
    )

    # 1) Sections PBXBuildFile / PBXFileReference : insertion avant la fin.
    text = text.replace(
        "/* End PBXBuildFile section */", build_block + "/* End PBXBuildFile section */", 1
    )
    text = text.replace(
        "/* End PBXFileReference section */",
        ref_block + "/* End PBXFileReference section */",
        1,
    )

    # 2) Enfants du groupe « Duello ».
    group_re = re.compile(
        r"(\t\tAE000001AAAAAAAAAAAAAA02 /\* Duello \*/ = \{\n"
        r"\t\t\tisa = PBXGroup;\n"
        r"\t\t\tchildren = \(\n)(.*?)(\t\t\t\);)",
        re.S,
    )
    match = group_re.search(text)
    if not match:
        print("Groupe « Duello » introuvable dans le pbxproj.", file=sys.stderr)
        return 1
    text = text[: match.end(2)] + children_block + text[match.end(2) :]

    # 3) Phase de compilation « Sources ».
    sources_re = re.compile(
        r"(\t\tAD000002AAAAAAAAAAAAAA01 /\* Sources \*/ = \{\n"
        r"\t\t\tisa = PBXSourcesBuildPhase;\n"
        r"\t\t\tbuildActionMask = 2147483647;\n"
        r"\t\t\tfiles = \(\n)(.*?)(\t\t\t\);)",
        re.S,
    )
    match = sources_re.search(text)
    if not match:
        print("Phase « Sources » introuvable dans le pbxproj.", file=sys.stderr)
        return 1
    text = text[: match.end(2)] + sources_block + text[match.end(2) :]

    if text.count("{") != text.count("}"):
        print("Déséquilibre des accolades, écriture annulée.", file=sys.stderr)
        return 1

    PBX.write_text(text, encoding="utf-8")
    print(f"{len(missing)} fichier(s) ajouté(s) au projet :")
    for name in missing:
        print(f"  - {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
