"""Retrievers. Each returns [(chunk_id, score)], sorted descending.

'keyword' is exactly the algorithm from dev-context-mcp/lib/business-logic-parser.js -
it counts how many of the query tokens occur in the chunk. It is reproduced here so
the baseline comparison is fair.
"""

from __future__ import annotations

import re
from abc import ABC, abstractmethod
from functools import lru_cache

from rank_bm25 import BM25Okapi

from .corpus import Chunk, load

RE_TOKEN = re.compile(r"[a-zA-Z_][a-zA-Z0-9_]+")


def tokenize(text: str) -> list[str]:
    """Tokens + camelCase/snake_case splitting, because queries are prose
    while code is getStoreOrderTotals."""
    out: list[str] = []
    for t in RE_TOKEN.findall(text):
        out.append(t.lower())
        parts = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", t).replace("_", " ").split()
        if len(parts) > 1:
            out.extend(p.lower() for p in parts)
    return out


class Retriever(ABC):
    name: str

    @abstractmethod
    def search(self, query: str, k: int = 10) -> list[tuple[str, float]]:
        ...


class KeywordRetriever(Retriever):
    """The baseline: +1 for every query token that occurs in the chunk."""

    name = "keyword"

    def __init__(self, chunks: tuple[Chunk, ...]):
        self.chunks = chunks
        self.lowered = [c.text.lower() for c in chunks]

    def search(self, query: str, k: int = 10) -> list[tuple[str, float]]:
        tokens = {t for t in tokenize(query)}
        scored = []
        for c, low in zip(self.chunks, self.lowered):
            score = sum(1 for t in tokens if t in low)
            if score:
                scored.append((c.id, float(score)))
        scored.sort(key=lambda x: -x[1])
        return scored[:k]


class BM25Retriever(Retriever):
    name = "bm25"

    def __init__(self, chunks: tuple[Chunk, ...]):
        self.chunks = chunks
        self.ids = [c.id for c in chunks]
        self.bm25 = BM25Okapi([tokenize(c.text) for c in chunks])

    def search(self, query: str, k: int = 10) -> list[tuple[str, float]]:
        scores = self.bm25.get_scores(tokenize(query))
        ranked = sorted(zip(self.ids, scores), key=lambda x: -x[1])
        return [(i, float(s)) for i, s in ranked[:k] if s > 0]


@lru_cache(maxsize=1)
def registry() -> dict[str, Retriever]:
    chunks = load()
    return {r.name: r for r in (KeywordRetriever(chunks), BM25Retriever(chunks))}


def get(name: str) -> Retriever:
    reg = registry()
    if name not in reg:
        raise KeyError(f"no retriever {name!r}; available: {', '.join(reg)}")
    return reg[name]
