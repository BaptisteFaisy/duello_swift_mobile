#!/usr/bin/env python3
"""Périmètre du pré-contrôle Swift sous Linux.

Sous Linux, Charts, PDFKit, PhotosUI… n'existent pas : `swiftc` ne peut
contrôler les TYPES que des fichiers « portables » — ceux qui n'importent que
Foundation / UIKit / Security / Combine / GoogleSignIn / SwiftUI. Les autres ne
sont contrôlés qu'en syntaxe (`-parse`). SwiftUI est couvert par le shim
`scripts/linux-shims/SwiftUI*.swift` (faux module, jamais livré).

Il reste un faux positif structurel : un fichier portable peut citer un type
déclaré dans un fichier non portable (un modèle qui utilise un type dont la
déclaration voisine vit dans une vue). Le type existe bel et bien ; c'est le
lot qui ne le voit pas. Ce script sépare ces échecs-là — qu'il tait, en les
rapportant — des échecs réels, qui doivent faire échouer le contrôle.

Sous-commandes :
    list      chemins des fichiers portables, un par ligne.
    triage    lit des diagnostics `swiftc` sur stdin, écarte les faux positifs,
              affiche ce qui reste ; sort en 1 s'il reste une erreur réelle.
"""
from __future__ import annotations

import pathlib
import re
import sys

PORTABLE_IMPORTS = re.compile(
    r"^import (Foundation|UIKit|Security|Combine|GoogleSignIn|SwiftUI)$"
)
IMPORTS = re.compile(r"^import .*$", re.M)
# Déclaration de type en tête de ligne : [modificateurs] struct|class|enum|…
DECLARATION = re.compile(
    r"^\s*(?:(?:public|internal|private|fileprivate|open|final|indirect|@\w+)\s+)*"
    r"(?:struct|class|enum|protocol|actor|typealias)\s+([A-Za-z_]\w*)",
    re.M,
)
# `chemin.swift:ligne:colonne: error: message`
DIAGNOSTIC = re.compile(
    r"^(?P<file>.+?\.swift):\d+:\d+: (?P<kind>error|warning|note): (?P<message>.*)$"
)
# Symboles absents du lot : « cannot find type 'X' in scope » et variantes.
MISSING = re.compile(r"cannot find (?:type |value )?'(?P<name>[A-Za-z_]\w*)'")


def source_dir() -> pathlib.Path:
    return pathlib.Path(__file__).resolve().parent.parent / "Duello"


def sources() -> dict[str, str]:
    return {f.name: f.read_text(errors="replace") for f in source_dir().glob("*.swift")}


def is_portable(text: str) -> bool:
    return all(PORTABLE_IMPORTS.match(line) for line in IMPORTS.findall(text))


def portable_names(texts: dict[str, str]) -> list[str]:
    return sorted(name for name, text in texts.items() if is_portable(text))


def declared(text: str) -> set[str]:
    return set(DECLARATION.findall(text))


def triage(texts: dict[str, str]) -> int:
    """Écarte les faux positifs d'un flot de diagnostics `swiftc`."""
    portable = set(portable_names(texts))
    declared_elsewhere = {
        name
        for filename, text in texts.items()
        if filename not in portable
        for name in declared(text)
    } - {name for filename, text in texts.items() if filename in portable for name in declared(text)}

    errors: dict[str, list[tuple[str, str]]] = {}
    for line in sys.stdin:
        match = DIAGNOSTIC.match(line.rstrip("\n"))
        if not match or match.group("kind") != "error":
            continue
        errors.setdefault(pathlib.Path(match.group("file")).name, []).append(
            (line.rstrip("\n"), match.group("message"))
        )

    out_of_scope: dict[str, str] = {}
    real: list[str] = []
    for filename, entries in sorted(errors.items()):
        culprit = next(
            (
                missing.group("name")
                for _, message in entries
                if (missing := MISSING.search(message))
                and missing.group("name") in declared_elsewhere
            ),
            None,
        )
        if culprit:
            out_of_scope[filename] = culprit
            continue
        real.extend(line for line, _ in entries)

    for filename, culprit in sorted(out_of_scope.items()):
        print(f"hors couverture : {filename} (cite « {culprit} », déclaré hors lot)")
    for line in real:
        print(line)
    if real:
        print(f"\n{len(real)} erreur(s) réelle(s) dans le lot portable.")
        return 1
    print(f"aucune erreur dans le lot portable ({len(out_of_scope)} fichier(s) hors couverture).")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] not in {"list", "triage"}:
        print(__doc__, file=sys.stderr)
        return 2
    texts = sources()
    if not texts:
        print("aucun fichier .swift dans Duello/", file=sys.stderr)
        return 2
    if argv[1] == "list":
        print("\n".join(portable_names(texts)))
        return 0
    return triage(texts)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
