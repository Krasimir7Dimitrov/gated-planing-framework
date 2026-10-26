"""Builds the gold set and writes it as JSONL + a report.

    python -m retrieval_eval.goldset.build
    python -m retrieval_eval.goldset.build --stats-only
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import Counter
from dataclasses import asdict
from pathlib import Path

from ..config import CORPORA, DOC_FILES, EXCLUDE_PARTS, GOLDSET_DIR
from . import markdown as md
from .php import GoldPair, extract_file


def iter_php(root: Path, src_dirs: list[str]):
    for d in src_dirs:
        base = root / d
        if not base.exists():
            continue
        for p in base.rglob("*.php"):
            if EXCLUDE_PARTS & set(p.parts):
                continue
            yield p


def build() -> tuple[list[GoldPair], Counter, Counter]:
    pairs: list[GoldPair] = []
    skipped: Counter = Counter()
    files_seen: Counter = Counter()

    for name, cfg in CORPORA.items():
        root: Path = cfg["root"]
        if not root.exists():
            print(f"  ! skipped corpus {name}: {root} does not exist")
            continue
        for php in iter_php(root, cfg["src_dirs"]):
            files_seen[name] += 1
            got, sk = extract_file(php, root, name)
            pairs.extend(got)
            skipped.update(sk)

    for doc in DOC_FILES:
        if not doc.exists():
            print(f"  ! skipped document: {doc}")
            continue
        files_seen["docs"] += 1
        for ch in md.parse_chunks(doc):
            if not ch.content or len(ch.content) < 80:
                skipped["thin_section"] += 1
                continue
            # A top-level header with no parent ("What is it") is not a query -
            # it is too generic to tell one section from another.
            if ch.level == 1 or (">" not in ch.header_path and len(ch.title.split()) < 3):
                skipped["generic_header"] += 1
                continue
            pairs.append(GoldPair(
                query=ch.header_path, query_type="doc_section",
                gold_file=doc.name, gold_line=ch.line_start,
                gold_symbol=ch.header_path, corpus="docs", source="markdown:header",
            ))

    # deduplicate by (query, correct answer)
    seen: set[str] = set()
    unique: list[GoldPair] = []
    for p in pairs:
        key = hashlib.sha1(f"{p.query}|{p.gold_file}|{p.gold_line}".encode()).hexdigest()
        if key in seen:
            skipped["duplicate"] += 1
            continue
        seen.add(key)
        unique.append(p)

    # a query pointing at several different answers is ambiguous - left out of the set
    by_query: Counter = Counter(p.query for p in unique)
    ambiguous = {q for q, c in by_query.items() if c > 1}
    final = [p for p in unique if p.query not in ambiguous]
    skipped["ambiguous_query"] = len(unique) - len(final)

    return final, skipped, files_seen


def main() -> None:
    # The Windows console defaults to cp1252 - otherwise non-ASCII output breaks
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except (AttributeError, OSError):
            pass

    ap = argparse.ArgumentParser()
    ap.add_argument("--stats-only", action="store_true")
    args = ap.parse_args()

    print("Building gold set...\n")
    pairs, skipped, files_seen = build()

    by_type = Counter(p.query_type for p in pairs)
    by_corpus = Counter(p.corpus for p in pairs)
    gold_files = len({p.gold_file for p in pairs})

    print("=" * 62)
    print(f"  files read             {sum(files_seen.values())} " +
          f"({', '.join(f'{k}:{v}' for k, v in files_seen.items())})")
    print(f"  PAIRS                  {len(pairs)}")
    print(f"  unique targets         {gold_files} files")
    print()
    print("  by query type")
    for t, c in by_type.most_common():
        print(f"    {t:<18} {c:>5}")
    print()
    print("  by corpus")
    for t, c in by_corpus.most_common():
        print(f"    {t:<18} {c:>5}")
    print()
    print("  rejected")
    for t, c in skipped.most_common():
        print(f"    {t:<18} {c:>5}")

    if pairs:
        print()
        print("  examples")
        shown: set[str] = set()
        for p in pairs:
            if p.query_type in shown:
                continue
            shown.add(p.query_type)
            q = p.query if len(p.query) <= 65 else p.query[:65] + "..."
            print(f"    [{p.query_type}] {q}")
            print(f"      -> {p.gold_file}:{p.gold_line} ({p.gold_symbol})")

    if args.stats_only:
        return

    GOLDSET_DIR.mkdir(parents=True, exist_ok=True)
    out = GOLDSET_DIR / "auto.jsonl"
    with out.open("w", encoding="utf-8") as fh:
        for i, p in enumerate(pairs):
            rec = asdict(p)
            rec["id"] = f"auto-{i:04d}"
            fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
    print(f"\n  written -> {out}")

    meta = GOLDSET_DIR / "auto.meta.json"
    meta.write_text(json.dumps({
        "pairs": len(pairs), "gold_files": gold_files,
        "by_type": dict(by_type), "by_corpus": dict(by_corpus),
        "skipped": dict(skipped), "files_read": dict(files_seen),
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"  report -> {meta}\n")


if __name__ == "__main__":
    main()