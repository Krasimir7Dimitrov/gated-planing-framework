"""Markdown chunking by header path - the same logic as
dev-context-mcp/lib/business-logic-parser.js, so the comparison is fair.

The query is the header path; the correct answer is the section.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

RE_HEADER = re.compile(r"^(#{1,6})\s+(.+?)\s*$")


@dataclass
class Chunk:
    header_path: str
    title: str
    level: int
    content: str
    line_start: int
    file: str


def parse_chunks(path: Path) -> list[Chunk]:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    stack: list[str | None] = [None] * 6
    chunks: list[Chunk] = []
    cur: dict | None = None
    buf: list[str] = []

    def flush() -> None:
        if cur is not None:
            chunks.append(Chunk(
                header_path=cur["header_path"], title=cur["title"], level=cur["level"],
                content="\n".join(buf).strip(), line_start=cur["line_start"],
                file=path.name,
            ))

    for i, line in enumerate(lines):
        m = RE_HEADER.match(line)
        if m:
            flush()
            buf = []
            level = len(m.group(1))
            title = m.group(2).strip()
            stack[level - 1] = title
            for j in range(level, 6):
                stack[j] = None
            cur = {
                "level": level, "title": title, "line_start": i + 1,
                "header_path": " > ".join(s for s in stack if s),
            }
        elif cur is not None:
            buf.append(line)
    flush()
    return chunks
