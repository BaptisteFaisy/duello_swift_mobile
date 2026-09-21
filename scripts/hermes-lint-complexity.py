#!/usr/bin/env python3
"""hermes-lint-complexity.py — garde-fou des limites de complexité Duello (Hermes).

Règles (AGENTS.md du projet Duello, applicables au code mobile) :
  - maximum 50 lignes par fonction ;
  - maximum 10 fonctions par fichier ;
  - maximum 500 lignes par fichier.

Ce script ne punit PAS l'existant : il fonctionne comme un **ratchet**, comme la
baseline `.github/test-baseline.txt` du dépôt `duello`. Une violation déjà
enregistrée dans la baseline ne bloque pas ; seule une NOUVELLE violation
(nouveau fichier, ou seuil aggravé) fait rougir la batterie. Sans ça, Hermes
ne mergerait plus jamais rien, et une PR serait condamnée pour une raison
qu'elle n'a pas causée.

Usage :
  hermes-lint-complexity.py [--lang swift|kotlin|auto] [--root DIR]
                            [--baseline FICHIER] [--update-baseline] [--quiet]

Sortie : 0 = aucune nouvelle régression ; 1 = régressions introduites par la PR.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

MAX_FUNC_LINES = 50
MAX_FUNCS_PER_FILE = 10
MAX_FILE_LINES = 500

# Fichiers générés / données volumineuses : exemptés (l'AGENTS.md l'autorise).
GENERATED = re.compile(r"\.(generated|json|pbxproj|xcconfig|plist)$|/Generated|\.generated\.", re.I)
# build/.gradle/Pods : artefacts. _stray : code mis de côté, absent du target Xcode
# (Duello.xcodeproj ne le référence pas) — le mesurer punirait une PR pour des
# fichiers que personne ne compile.
SKIP_DIRS = {".git", "build", ".gradle", "node_modules", "DerivedData", ".swiftpm",
             "Pods", "_stray"}

SWIFT_FUNC = re.compile(r"^\s*(?:@\w+\s+)*(?:public |internal |private |fileprivate |open )?"
                        r"(?:static |class |final |override |mutating |consuming |nonisolated |)*"
                        r"func\s+([A-Za-z_][\w]*)")
KOTLIN_FUNC = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:public |internal |private |protected |open |final |"
                         r"abstract |override |suspend |inline |operator |infix |external |tailrec |)"
                         r"fun\s+(?:<[^>]+>\s*)?([A-Za-z_][\w]*)")


def _iter_sources(root: Path, lang: str):
    exts = {".swift"} if lang == "swift" else {".kt"}
    for p in sorted(root.rglob("*")):
        if not p.is_file() or p.suffix not in exts:
            continue
        if any(part in SKIP_DIRS for part in p.parts):
            continue
        if GENERATED.search(p.name) or GENERATED.search(str(p)):
            continue
        yield p


def _strip_noise(text: str) -> list[tuple[str, bool]]:
    """Retourne [(ligne, compte_comme_code)] — les lignes de commentaire et les
    lignes vides ne comptent pas dans la longueur d'une fonction."""
    out = []
    in_block = False
    for raw in text.splitlines():
        line = raw.strip()
        if in_block:
            out.append(("", False))
            if "*/" in line:
                in_block = False
            continue
        if line.startswith("/*"):
            out.append(("", False))
            if "*/" not in line:
                in_block = True
            continue
        if not line or line.startswith("//"):
            out.append(("", False))
            continue
        out.append((raw, True))
    return out


def analyze(path: Path, lang: str) -> dict:
    text = path.read_text(encoding="utf-8", errors="replace")
    pat = SWIFT_FUNC if lang == "swift" else KOTLIN_FUNC
    lines = text.splitlines()
    marked = _strip_noise(text)
    funcs = []
    i = 0
    n = len(lines)
    while i < n:
        m = pat.match(lines[i])
        if not m:
            i += 1
            continue
        name = m.group(1)
        # Corps à expression (`fun x() = ...`) : 1 ligne, pas d'accolade.
        j = i
        brace = None
        while j < min(i + 12, n):
            k = lines[j].find("{")
            if k != -1:
                brace = j
                break
            if lang == "kotlin" and re.search(r"\)\s*=\s*\S", lines[j]) :
                break
            if lang == "swift" and re.search(r"\)\s*(->[^{]*)?\{?\s*$", lines[j]) and "{" not in lines[j]:
                # signature multi-lignes : on continue à chercher l'accolade
                pass
            j += 1
        if brace is None:
            funcs.append({"name": name, "line": i + 1, "lines": 1})
            i += 1
            continue
        depth = 0
        end = brace
        for k in range(brace, n):
            depth += lines[k].count("{") - lines[k].count("}")
            if depth <= 0:
                end = k
                break
        body = marked[brace:end + 1]
        code_lines = sum(1 for _, is_code in body if is_code)
        funcs.append({"name": name, "line": brace + 1, "lines": max(code_lines, end - brace + 1)})
        i = end + 1
    return {
        "path": str(path),
        "file_lines": len(lines),
        "funcs": funcs,
    }


def violations(info: dict) -> list[str]:
    out = []
    if info["file_lines"] > MAX_FILE_LINES:
        out.append("fichier %d lignes (> %d)" % (info["file_lines"], MAX_FILE_LINES))
    if len(info["funcs"]) > MAX_FUNCS_PER_FILE:
        out.append("%d fonctions (> %d)" % (len(info["funcs"]), MAX_FUNCS_PER_FILE))
    for f in info["funcs"]:
        if f["lines"] > MAX_FUNC_LINES:
            out.append("fonction %s(): %d lignes (> %d) @%d" % (
                f["name"], f["lines"], MAX_FUNC_LINES, f["line"]))
    return out


def fingerprint(rel: str, vs: list[str]) -> list[str]:
    """Lignes de baseline : une par violation, sans numéro de ligne.

    Une ligne par violation, et non un bloc par fichier : la granularité du
    ratchet est la violation elle-même. Si une PR répare trois dépassements et en
    introduit un quatrième, seules la (ou les) nouvelle(s) ligne(s) bloquent.

    Le numéro de ligne est retiré (`@123`) : un simple décalage dû au contexte
    d'un rebase ne doit pas créer une « nouvelle » violation, ni masquer une
    ancienne. La mesure (nom de fonction, nombre de lignes) reste, elle, intacte.
    """
    return sorted("%s :: %s" % (rel, re.sub(r"@\d+$", "", v).rstrip()) for v in vs)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", default="auto", choices=["auto", "swift", "kotlin"])
    ap.add_argument("--root", default=".")
    ap.add_argument("--baseline", default=".github/hermes-baseline.txt")
    ap.add_argument("--update-baseline", action="store_true")
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()

    root = Path(a.root).resolve()
    langs = ["swift", "kotlin"] if a.lang == "auto" else [a.lang]
    found = []
    for lang in langs:
        for p in _iter_sources(root, lang):
            info = analyze(p, lang)
            vs = violations(info)
            if vs:
                found.extend(fingerprint(str(p.relative_to(root)), vs))

    base_path = Path(a.baseline)
    if not base_path.is_absolute():
        base_path = root / base_path
    baseline = set()
    if base_path.exists():
        baseline = {b.rstrip() for b in base_path.read_text(encoding="utf-8").splitlines() if b.strip()}
    all_fp = "\n".join(sorted(set(found)))
    found = sorted(set(found))

    new = [fp for fp in found if fp not in baseline]
    if a.update_baseline:
        base_path.parent.mkdir(parents=True, exist_ok=True)
        base_path.write_text(all_fp + ("\n" if all_fp else ""), encoding="utf-8")
        print("[lint] baseline écrite : %d violation(s) figée(s) (%s)" % (
            len(found), base_path))
        return 0
    if not new:
        print("[lint] OK — %d violation(s) constatée(s), %d nouvelle(s) : aucune régression introduite."
              % (len(found), len(new)))
        return 0
    print("[lint] RÉGRESSION de complexité : %d nouvelle(s) violation(s) :" % len(new))
    for fp in new[:40]:
        print("  - " + fp.replace("\n", "\n    "))
    if len(new) > 40:
        print("  ... %d de plus" % (len(new) - 40))
    print("[lint] Soit découper en modules à responsabilité claire, soit (exception "
          "justifiée) valider la baseline : `python3 scripts/hermes-lint-complexity.py "
          "--update-baseline` + commit du fichier de baseline.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
