#!/usr/bin/env python3
"""Synchronise `Duello.xcodeproj/project.pbxproj` avec le dossier `Duello/`.

Le projet Xcode de Duello liste explicitement chaque fichier source (pas de
groupe synchronisé du système de fichiers). Ajouter ou retirer un `.swift` à la
main dans les quatre sections du pbxproj est fastidieux et source d'erreurs ;
ce script le fait de façon déterministe et idempotente :

- PBXBuildFile      (l'entrée de compilation)
- PBXFileReference  (la référence de fichier)
- PBXGroup « Duello » (l'arborescence)
- PBXSourcesBuildPhase (la phase de compilation)

Il **ajoute** les fichiers présents sur disque et **retire** les références des
fichiers supprimés (nécessaire quand un gros fichier est découpé en modules).

Usage : `python3 scripts/sync_xcode_sources.py [--check]`
  --check : n'écrit rien, sort en code 1 si une resynchronisation est requise.
"""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PBX = ROOT / "Duello.xcodeproj" / "project.pbxproj"
SRC_DIR = ROOT / "Duello"

# Sections du pbxproj : (marqueur de fin, gabarit d'une ligne)
BUILD_SECTION = "/* End PBXBuildFile section */"
REF_SECTION = "/* End PBXFileReference section */"


def stable_id(name: str, kind: str) -> str:
    """Identifiant 24 caractères hexadécimaux, dérivé du nom (déterministe)."""
    digest = hashlib.sha1(f"{kind}:{name}".encode("utf-8")).hexdigest().upper()
    return digest[:24]


def referenced_names(text: str) -> set[str]:
    """Noms de fichiers .swift déjà présents dans le pbxproj.

    Couvre les deux formes de commentaire Xcode et les noms contenant `+`
    (`TrainingCatalogView+Entry.swift`) ou `-`.
    """
    pattern = r"/\* ([A-Za-z0-9_+-]+\.swift)(?: in Sources)? \*/"
    return set(re.findall(pattern, text))


# Caractères autorisés dans une chaîne nue du format OpenStep (pbxproj). Tout
# autre caractère — notamment le `+` de `Vue+Extension.swift` — exige des
# guillemets, sinon Xcode refuse le projet entier (« missing semicolon in
# dictionary », constaté par le build macOS du 2026-09-22).
_BARE = re.compile(r"[A-Za-z0-9_$/:.-]+\Z")


def pbx_path(name: str) -> str:
    """Valeur `path = …` valide : nue si possible, quotée sinon."""
    if _BARE.match(name):
        return name
    return '"{}"'.format(name.replace('"', '\\"'))


def requote_paths(text: str) -> str:
    """Quote les `path = …` nus invalides déjà présents dans le pbxproj."""

    def fix(match: re.Match) -> str:
        val = match.group(1)
        if _BARE.match(val):
            return match.group(0)
        return "path = " + pbx_path(val) + ";"

    return re.sub(r"path = ([^\"\s;][^;\n]*);", fix, text)


def prune(text: str, stale: set[str]) -> str:
    """Retire du pbxproj toute ligne citant un fichier supprimé.

    Les références apparaissent sous deux formes : `/* X.swift */` (référence
    de fichier, enfant de groupe) et `/* X.swift in Sources */` (phase de
    compilation). Les deux doivent disparaître.
    """
    if not stale:
        return text
    needles = []
    for name in stale:
        needles.append(f"/* {name} */")
        needles.append(f"/* {name} in Sources */")
    kept = []
    for line in text.splitlines(keepends=True):
        if any(needle in line for needle in needles):
            continue
        kept.append(line)
    return "".join(kept)


def insert_children(text: str, block: str) -> str:
    group_re = re.compile(
        r"(\t\tAE000001AAAAAAAAAAAAAA02 /\* Duello \*/ = \{\n"
        r"\t\t\tisa = PBXGroup;\n"
        r"\t\t\tchildren = \(\n)(.*?)(\t\t\t\);)",
        re.S,
    )
    match = group_re.search(text)
    if not match:
        raise SystemExit("Groupe « Duello » introuvable dans le pbxproj.")
    return text[: match.end(2)] + block + text[match.end(2) :]


def insert_sources(text: str, block: str) -> str:
    sources_re = re.compile(
        r"(\t\tAD000002AAAAAAAAAAAAAA01 /\* Sources \*/ = \{\n"
        r"\t\t\tisa = PBXSourcesBuildPhase;\n"
        r"\t\t\tbuildActionMask = 2147483647;\n"
        r"\t\t\tfiles = \(\n)(.*?)(\t\t\t\);)",
        re.S,
    )
    match = sources_re.search(text)
    if not match:
        raise SystemExit("Phase « Sources » introuvable dans le pbxproj.")
    return text[: match.end(2)] + block + text[match.end(2) :]


def main() -> int:
    check = "--check" in sys.argv[1:]
    if not PBX.exists():
        print(f"pbxproj introuvable : {PBX}", file=sys.stderr)
        return 1

    text = PBX.read_text(encoding="utf-8")
    fixed = requote_paths(text)
    requoted = fixed != text
    if requoted:
        if check:
            print("Guillemets OpenStep manquants : relancer sans --check.",
                  file=sys.stderr)
            return 1
        text = fixed
    on_disk = sorted(p.name for p in SRC_DIR.glob("*.swift"))
    known = referenced_names(text)

    stale = known - set(on_disk)
    missing = [name for name in on_disk if name not in known]

    if not stale and not missing and not requoted:
        print(f"Rien à faire : {len(on_disk)} fichiers .swift synchronisés.")
        return 0
    if check:
        print(f"Désynchronisé : {len(missing)} à ajouter, {len(stale)} à retirer.")
        return 1

    text = prune(text, stale)

    if missing:
        text = text.replace(
            BUILD_SECTION,
            "".join(
                f"\t\t{stable_id(n, 'build')} /* {n} in Sources */ = "
                f"{{isa = PBXBuildFile; fileRef = {stable_id(n, 'ref')} /* {n} */; }};\n"
                for n in missing
            )
            + BUILD_SECTION,
            1,
        )
        text = text.replace(
            REF_SECTION,
            "".join(
                f"\t\t{stable_id(n, 'ref')} /* {n} */ = {{isa = PBXFileReference; "
                f'lastKnownFileType = sourcecode.swift; path = {pbx_path(n)}; sourceTree = "<group>"; }};\n'
                for n in missing
            )
            + REF_SECTION,
            1,
        )
        text = insert_children(
            text,
            "".join(f"\t\t\t\t{stable_id(n, 'ref')} /* {n} */,\n" for n in missing),
        )
        text = insert_sources(
            text,
            "".join(
                f"\t\t\t\t{stable_id(n, 'build')} /* {n} in Sources */,\n"
                for n in missing
            ),
        )

    if text.count("{") != text.count("}"):
        print("Déséquilibre des accolades, écriture annulée.", file=sys.stderr)
        return 1

    PBX.write_text(text, encoding="utf-8")
    if missing:
        print(f"{len(missing)} fichier(s) ajouté(s) :")
        for name in missing:
            print(f"  + {name}")
    if stale:
        print(f"{len(stale)} fichier(s) retiré(s) :")
        for name in sorted(stale):
            print(f"  - {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
