"""FastAPI service: search over the code and docs + self-evaluation.

    uvicorn retrieval_eval.api:app --reload --port 8000

Open http://localhost:8000/docs for the interactive documentation.
"""

from __future__ import annotations

import time
from typing import Literal

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field

from .corpus import load
from .evaluate import load_goldset, run_all
from .retrievers import get, registry

app = FastAPI(
    title="retrieval-eval",
    version="0.1.0",
    description="Retrieval layer for the Pre-Implementation Protocol framework. "
                "Measures, and aims to replace, the word-count search in dev-context-mcp.",
)


class Hit(BaseModel):
    chunk_id: str
    file: str
    line: int
    symbol: str
    score: float
    preview: str


class SearchResponse(BaseModel):
    query: str
    retriever: str
    took_ms: float
    hits: list[Hit]


class HealthResponse(BaseModel):
    status: str
    chunks: int
    retrievers: list[str]
    goldset_size: int


@app.get("/health", response_model=HealthResponse, tags=["service"])
def health() -> HealthResponse:
    try:
        gold = len(load_goldset())
    except FileNotFoundError:
        gold = 0
    return HealthResponse(
        status="ok", chunks=len(load()),
        retrievers=sorted(registry()), goldset_size=gold,
    )


@app.get("/search", response_model=SearchResponse, tags=["search"])
def search(
    q: str = Query(..., min_length=2, description="Natural-language query"),
    retriever: Literal["keyword", "bm25"] = "bm25",
    k: int = Query(5, ge=1, le=50),
) -> SearchResponse:
    """Searches the PHP code (primary + secondary projects) and the documentation."""
    try:
        r = get(retriever)
    except KeyError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    by_id = {c.id: c for c in load()}
    t0 = time.perf_counter()
    results = r.search(q, k=k)
    took = (time.perf_counter() - t0) * 1000

    hits = []
    for cid, score in results:
        c = by_id.get(cid)
        if not c:
            continue
        hits.append(Hit(
            chunk_id=cid, file=c.file, line=c.line, symbol=c.symbol,
            score=round(score, 4),
            preview=" ".join(c.text.split())[:220],
        ))
    return SearchResponse(query=q, retriever=retriever, took_ms=round(took, 2), hits=hits)


class EvalResponse(BaseModel):
    goldset: str
    results: list[dict] = Field(..., description="One row per retriever")


@app.get("/eval", response_model=EvalResponse, tags=["evaluation"])
def evaluate_endpoint(
    goldset: str = "auto",
    k: int = Query(5, ge=1, le=20),
) -> EvalResponse:
    """Runs the gold set against every retriever and returns the metrics.

    This is the point: the service evaluates itself instead of claiming it works.
    """
    try:
        return EvalResponse(goldset=goldset, results=run_all(goldset=goldset, k=k))
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
