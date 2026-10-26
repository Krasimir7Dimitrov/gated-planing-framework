"""The search corpus: PHP symbols + markdown sections, reduced to chunks.

One chunk = one thing that can be the correct answer to a query.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from .config import CORPORA, DOC_FILES, EXCLUDE_PARTS
from .goldset import markdown as md

RE_SYMBOL = re.compile(
    r"^\s*(?:(?:final|abstract)\s+)?"
    r"(?:(?:public|protected|private)\s+)?(?:static\s+)?"
    r"(?:(?P<kind>function|class|interface|trait)\s+(?P<name>\w+)"
    r"|(?P<vis>public|protected|private)\s+(?:?:[\w\\/]+\s+)?\$(?P<prop>\w+))",
)


@dataclass
class Chunk:
    id: str
    file: str
    line: int
    symbol: str
    text: str
    corpus: str


def _php_chunks(path: Path, root: Path, corpus: str) -> list[Chunk]:
    """Splits a PHP file into symbols. The chunk text = the declaration plus the
    docblock above it and the body up to the next symbol - that is what a
    retriever actually has to compare against."""
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    rel = path.relative_to(root).as_posix()
    marks: list[tuple[int, str]] = []
    for i, line in enumerate(lines):
        m = RE_SYMBOL.match(line)
        if not m:
            continue
        name = m.group("name") or m.group("prop")
        kind = m.group("kind") or "property"
        if not name:
            continue
        marks.append((i, f"{kind} {name}"))

    out: list[Chunk] = []
    for idx, (i, symbol) in enumerate(marks):
        start = i
        # pull in the docblock/attributes directly above the declaration
        j = i - 1
        while j >= 0 and (lines[j].strip().startswith(("*", "/**", "*/", "#[", "//"))):
            start = j
            j -= 1
        end = marks[idx + 1][0] if idx + 1 < len(marks) else len(lines)
        body = "\n".join(lines[start:end]).strip()
        if not body:
            continue
        out.append(Chunk(
            id=f"{corpus}:{rel}:{i + 1}", file=rel, line=i + 1,
            symbol=f"{path.stem}::{symbol}", text=body[:4000], corpus=corpus,
        ))
    return out


@lru_cache(maxsize=1)
def load() -> tuple[Chunk, ...]:
    chunks: list[Chunk] = []
    for name, cfg in CORPORA.items():
        root: Path = cfg["root"]
        if not root.exists():
            continue
        for d in cfg["src_dirs"]:
            base = root / d
            if not base.exists():
                continue
            for p in base.rglob("*.php"):
                if EXCLUDE_PARTS & set(p.parts):
                    continue
                chunks.extend(_php_chunks(p, root, name))

    for doc in DOC_FILES:
        if not doc.exists():
            continue
        for ch in md.parse_chunks(doc):
            if not ch.content:
                continue
            chunks.append(Chunk(
                id=f"docs:{doc.name}:{ch.line_start}", file=doc.name,
                line=ch.line_start, symbol=ch.header_path,
                text=f"{ch.header_path}\n{ch.content}"[:4000], corpus="docs",
            ))
    return tuple(chunks)