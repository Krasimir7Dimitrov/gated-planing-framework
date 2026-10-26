"""Extracting (query, correct answer) pairs from PHP code.

The method is the one from CodeSearchNet: a docblock describes what a symbol does,
so it is the natural query, and the symbol's declaration is the correct answer. We
also extract Doctrine fields and Symfony routes, because the framework searches for
exactly those through get_entity_schema / get_routes.

Standard library only - on purpose. The set must be reproducible without installs.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

from ..config import MIN_QUERY_CHARS, MIN_QUERY_WORDS, TRIVIAL_DOC_PATTERNS

_TRIVIAL = [re.compile(p, re.IGNORECASE) for p in TRIVIAL_DOC_PATTERNS]


# /** ... */ -> [attributes] -> function name(
RE_DOC_FUNC = re.compile(
    r"/\*\*(?P<doc>.*?)\*/\s*"
    r"(?:#\[[^\]]*\]\s*)*"
    r"(?:(?:final|abstract)\s+)?"
    r"(?:public|protected|private)\s*(?:static\s+)?"
    r"function\s+(?P<name>\w+)\s*\(",
    re.DOTALL,
)

RE_DOC_CLASS = re.compile(
    r"/\*\*(?P<doc>.*?)\*/\s*"
    r"(?:#\[[^\]]*\]\s*)*"
    r"(?:(?:final|abstract)\s+)?"
    r"(?P<kind>class|interface|trait)\s+(?P<name>\w+)",
    re.DOTALL,
)

# PHP 8 attribute or docblock annotation for a Doctrine column/relation, followed by a property
RE_ORM_FIELD = re.compile(
    r"(?P<meta>#\[ORM\.(?:Column|ManyToOne|OneToMany|ManyToMany|OneToOne)\b.*?\]|/\*\*.*?\*/)",
    re.DOTALL,
)
RE_ROUTE = re.compile(
    r"(?P<meta>#\[Route\b.*?\]|/\*\*.*?@Route\((?P<ann_args>[^)]*)\).*?\*/)",
    re.DOTALL,
)
RE_PATH_ARG = re.compile(r"['\"]([^'\"]+)['\"]")
RE_NAME_ARG = re.compile(r"name\s*[:=]\s*['\"]([^'\"]+)['\"]")
RE_ORM_KIND = re.compile(r"ORM\.(Column|ManyToOne|OneToMany|ManyToMany|OneToOne)")
RE_ORM_TYPE = re.compile(r"type\s*[:=]\s*['\"](\w+)['\"]")
RE_TARGET = re.compile(r"targetEntity\s*[:=]\s*(?:['\"]([\w\\]+)['\"]|([\w\\]+)::class)")

@dataclass
class GoldPair:
    query: str
    query_type: str
    gold_file: str
    gold_line: int
    gold_symbol: str
    corpus: str
    source: str


def _line_of(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def clean_docblock(raw: str) -> str:
    """Docblock -> plain prose.

    Strips the asterisks, @-tags and multi-line annotations such as
    @UniqueEntity(fields={...}, message="..."), whose continuation lines do not
    start with @ and would otherwise leak into the query.
    """
    stripped = [re.sub(r"^\s*\*?\s*", "", ln).rstrip() for ln in raw.splitlines()]
    lines: list[str] = []
    depth = 0
    for line in stripped:
        if depth == 0 and not line.strip():
            continue
        if depth == 0 and line.lstrip().startswith("@"):
            depth = line.count("(") - line.count(")")
            continue
        if depth > 0:                   # inside a multi-line annotation
            depth += line.count("(") - line.count(")")
            continue
        lines.append(line.strip())
    text = re.sub(r"\s+", " ", " ".join(lines)).strip()
    # leftovers of code that slipped into a docblock
    if re.search(r"[;{}]\s*\w*\s*=", text):

        return ""
    return text


def is_trivial(text: str) -> bool:
    if not text:
        return True
    if len(text) < MIN_QUERY_CHARS or len(text.split()) < MIN_QUERY_WORDS:
        return True
    return any(p.match(text) for p in _TRIVIAL)


def _rel(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


def extract_file(path: Path, root: Path, corpus: str) -> tuple[list[GoldPair], dict[str, int]]:
    text = path.read_text(encoding="utf-8", errors="replace")
    rel = _rel(path, root)
    pairs: list[GoldPair] = []
    skipped = {"trivial_doc": 0}

    for m in RE_DOC_FUNC.finditer(text):
        doc = clean_docblock(m.group("doc"))
        if is_trivial(doc):
            skipped["trivial_doc"] += 1
            continue
        pairs.append(GoldPair(
            query=doc, query_type="method_doc",
            gold_file=rel, gold_line=_line_of(text, m.end("name")),
            gold_symbol=f"{path.stem}::{m.group('name')}()",
            corpus=corpus, source="php:docblock",
        ))

    for m in RE_DOC_CLASS.finditer(text):
        doc = clean_docblock(m.group("doc"))
        if is_trivial(doc):
            skipped["trivial_doc"] += 1
            continue
        pairs.append(GoldPair(
            query=doc, query_type="class_doc",
            gold_file=rel, gold_line=_line_of(text, m.end("name")),
            gold_symbol=f"{m.group('kind')} {m.group('name')}",
            corpus=corpus, source="php:docblock",
        ))

    for m in RE_ORM_FIELD.finditer(text):
        meta = m.group("meta")
        kinds = RE_ORM_KIND.findall(meta)
        if not kinds:
            continue
        kind = kinds[0]
        field = m.group("name")
        entity = path.stem
        col_type = RE_ORM_TYPE.search(meta)
        target = RE_TARGET.search(meta)
        if kind == "Column":
            t = col_type.group(1) if col_type else (m.group("type") or "").strip().lstrip("?") or "unknown"
            query = f"Which field of {entity} stores {field} and what type is it ({t})?"
            qt = "orm_column"
        else:
            tgt = (target.group(1) or target.group(2)) if target else "?"
            tgt = tgt.split("\\")[-1]
            query = f"What is the {kind} relation between {entity} and {tgt} through the field {field}?"
            qt = "orm_relation"
        pairs.append(GoldPair(
            query=query, query_type=qt,
            gold_file=rel, gold_line=_line_of(text, m.end("name")),
            gold_symbol=f"{entity}::${field}",
            corpus=corpus, source="php:doctrine",
        ))

    for m in RE_ROUTE.finditer(text):
        args = m.group("attr_args") or m.group("ann_args") or ""
        path_m = RE_PATH_ARG.search(args)
        name_m = RE_NAME_ARG.search(args)
        if not path_m and not name_m:
            continue
        route_path = path_m.group(1) if path_m else "?"
        route_name = name_m.group(1) if name_m else "?"
        query = f"Which controller handles the route {route_path} (name: {route_name})?"
        pairs.append(GoldPair(
            query=query, query_type="route",
            gold_file=rel, gold_line=_line_of(text, m.end("name")),
            gold_symbol=f"{path.stem}::{m.group('name')}()",
            corpus=corpus, source="php:route",
        ))

    return pairs, skipped
