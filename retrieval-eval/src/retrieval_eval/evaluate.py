"""Retrieval metrics and running the gold set.

P@k - how many of the k returned results are correct
MRR - 1 / the rank of the first correct result
nDCG@k - rewards the correct answer more the higher it is ranked
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path

from .config import GOLDSET_DIR
from .retrievers import get


@dataclass
class GoldItem:
    id: str
    query: str
    query_type: str
    gold_file: str
    gold_line: int
    corpus: str


def load_goldset(name: str = "auto") -> list[GoldItem]:
    path = GOLDSET_DIR / f"{name}.jsonl"
    if not path.exists():
        raise FileNotFoundError(f"no {path} - run `ctx goldset build` first")
    items = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        r = json.loads(line)
        items.append(GoldItem(
            id=r["id"], query=r["query"], query_type=r["query_type"],
            gold_file=r["gold_file"], gold_line=r["gold_line"], corpus=r["corpus"],
        ))
    return items


def is_hit(chunk_id: str, item: GoldItem, line_tolerance: int = 40) -> bool:
    """Correct if the chunk is from the right file and covers the right line.

    The tolerance exists because a chunk starts at the declaration, while the
    gold line may be a few lines inside it. Too large a tolerance makes the
    metric meaningless - 40 lines is roughly one method.
    """
    try:
        _, corpus, file, line = chunk_id.split(":", 3)
    except ValueError:
        return False
    if not item.gold_file.endswith(file) and not file.endswith(item.gold_file):
        return False
    return abs(int(line) - item.gold_line) <= line_tolerance


def evaluate(retriever_name: str, items: list[GoldItem], k: int = 5,
             ndcg_k: int = 10) -> dict:
    r = get(retriever_name)
    p_at_k, rr, ndcg, found = 0.0, 0.0, 0.0, 0.0
    per_type: dict[str, list[int]] = {}

    for item in items:
        results = r.search(item.query, k=max(k, ndcg_k))
        hits = [is_hit(cid, item) for cid, _ in results]
        top_k = hits[:k]
        p_at_k += (1.0 if any(top_k) else 0.0)    # success@k
        rank = next((i + 1 for i, h in enumerate(hits) if h), None)
        if rank:
            found += 1
            rr += 1.0 / rank
            if rank <= ndcg_k:
                ndcg += 1.0 / math.log2(rank + 1)
        per_type.setdefault(item.query_type, []).append(1 if any(top_k) else 0)

    n = max(1, len(items))
    return {
        "retriever": retriever_name,
        "n": len(items),
        f"success@{k}": round(p_at_k / n, 4),
        "MRR": round(rr / n, 4),
        f"nDCG@{ndcg_k}": round(ndcg / n, 4),
        "recall_any": round(found / n, 4),
        "by_type": {t: round(sum(v) / len(v), 4) for t, v in sorted(per_type.items())},
    }


def run_all(goldset: str = "auto", k: int = 5) -> dict:
    items = load_goldset(goldset)
    from .retrievers import registry
    return {
        "goldset": goldset,
        "results": [evaluate(name, items, k=k) for name in registry()],
    }


def main() -> None:
    import sys
    for s in (sys.stdout, sys.stderr):
        try:
            s.reconfigure(encoding="utf-8")
        except (AttributeError, OSError):
            pass

    out = run_all()
    rows = out["results"]
    print()
    print("=" * 74)
    print(f" BASELINE - gold set '{out['goldset']}', {rows[0]['n']} pairs")
    print("=" * 74)
    print(f"{'retriever':<14}{'success@5':>11}{'MRR':>9}{'nDCG@10':>10}{'recall':>9}")
    for r in rows:
        print(f"{r['retriever']:<14}{r['success@5']:>11.3f}{r['MRR']:>9.3f}{r['nDCG@10']:>10.3f}{r['recall_any']:>9.3f}")
    print()
    print(" by query type (success@5)")
    types = sorted({t for r in rows for t in r["by_type"]})
    print(f"{'type':<16}" + "".join(f"{r['retriever']:>12}" for r in rows))
    for t in types:
        print(f"{t:<16}" + "".join(f"{r['by_type'].get(t, 0):>12.3f}" for r in rows))
    print()

    Path(GOLDSET_DIR).mkdir(parents=True, exist_ok=True)
    (GOLDSET_DIR / "baseline.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f" saved -> {GOLDSET_DIR / 'baseline.json'}\n")


if __name__ == "__main__":
    main()