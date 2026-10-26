"""ctx - CLI for the evaluation pipeline.

    python -m retrieval_eval.cli <command>

Six commands, one file, no dependencies beyond the ones already installed.
State is JSON files in data/runs/ - no database, no migrations.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from .config import DATA_DIR, GOLDSET_DIR, PRIMARY_ROOT, TELEMETRY_PATH

RUNS_DIR = DATA_DIR / "runs"
TELEMETRY_LOG = TELEMETRY_PATH


def _utf8() -> None:
    for s in (sys.stdout, sys.stderr):
        try:
            s.reconfigure(encoding="utf-8")
        except (AttributeError, OSError):
            pass


def _git_rev() -> str:
    try:
        out = subprocess.run(["git", "rev-parse", "--short", "HEAD"],
                             capture_output=True, text=True, timeout=5,
                             cwd=DATA_DIR.parent)
        return out.stdout.strip() or "-"
    except Exception:
        return "-"


# --- goldset -------------------------------------------------------------


def cmd_goldset_build(args: argparse.Namespace) -> int:
    from .goldset.build import main as build_main
    sys.argv = ["build"] + (["--stats-only"] if args.stats_only else [])
    build_main()
    return 0


def cmd_goldset_from_telemetry(args: argparse.Namespace) -> int:
    """Builds a labelling worklist from the agents' real queries.

    The telemetry knows WHAT was asked and whether it was found - but not what
    the correct answer is. So no gold is invented here; the output is a list with
    an empty gold_file field that a human fills in. Anything else would be a fake
    set that then measures itself.
    """
    if not TELEMETRY_LOG.exists():
        print(f"No {TELEMETRY_LOG}")
        print("Telemetry is filled when agents call the MCP tools.")
        print("Run 2-3 framework cycles and try again.")
        return 1

    rows = []
    for line in TELEMETRY_LOG.read_text(encoding="utf-8").splitlines():
        if line.strip():
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue

    if not rows:
        print("The log is empty.")
        return 1

    # Only the searching tools matter - get_routes/get_project_context have no query
    searchy = {"search_business_logic", "search_code", "get_lessons"}
    queries: dict[str, dict] = {}
    for r in rows:
        if r.get("tool") not in searchy:
            continue
        term = next((v for v in (r.get("query") or {}).values() if isinstance(v, str)), None)
        if not term:
            continue
        key = f"{r['tool']}|{term}"
        q = queries.setdefault(key, {"tool": r["tool"], "query": term, "calls": 0, "empty": 0})
        q["calls"] += 1
        q["empty"] += 1 if r.get("empty") else 0

    if not queries:
        print("No queries from searching tools in the log.")
        return 1

    from .retrievers import get
    from .corpus import load
    by_id = {c.id: c for c in load()}
    retr = get(args.retriever)

    out = GOLDSET_DIR / "telemetry_candidates.jsonl"
    out.parent.mkdir(parents=True, exist_ok=True)
    failed_only = 0
    with out.open("w", encoding="utf-8") as fh:
        for i, q in enumerate(sorted(queries.values(), key=lambda x: -x["empty"])):
            always_empty = q["empty"] == q["calls"]
            if args.failures_only and not always_empty:
                continue
            failed_only += 1 if always_empty else 0
            hits = retr.search(q["query"], k=5)
            fh.write(json.dumps({
                "id": f"tel-{i:04d}",
                "query": q["query"],
                "tool": q["tool"],
                "calls": q["calls"],
                "empty_calls": q["empty"],
                "always_empty": always_empty,
                "gold_file": None,   # filled in by hand
                "gold_line": None,   # +
                "candidates": [
                    {"file": by_id[cid].file, "line": by_id[cid].line,
                     "symbol": by_id[cid].symbol, "score": round(s, 3)}
                    for cid, s in hits if cid in by_id
                ],
            }, ensure_ascii=False) + "\n")

    total = sum(1 for _ in out.open(encoding="utf-8"))
    print(f"\n unique queries in the log  {len(queries)}")
    print(f" always empty              {failed_only}")
    print(f" written for labelling     {total}")
    print(f"\n -> {out}")
    print("\nFill in gold_file and gold_line for every row, then:")
    print(" python -m retrieval_eval.cli eval run --goldset telemetry\n")
    return 0


# --- eval ----------------------------------------------------------------


def _next_run_id() -> str:
    RUNS_DIR.mkdir(parents=True, exist_ok=True)
    existing = [int(p.name) for p in RUNS_DIR.iterdir() if p.is_dir() and p.name.isdigit()]
    return f"{max(existing) + 1:03d}" if existing else "001"


def cmd_eval_run(args: argparse.Namespace) -> int:
    from .evaluate import evaluate, is_hit, load_goldset
    from .retrievers import registry

    try:
        items = load_goldset(args.goldset)
    except FileNotFoundError as exc:
        print(exc)
        return 1

    run_id = _next_run_id()
    run_dir = RUNS_DIR / run_id
    run_dir.mkdir(parents=True, exist_ok=True)

    results = []
    failures = []
    for name, r in registry().items():
        results.append(evaluate(name, items, k=args.k))
        for it in items:
            res = r.search(it.query, k=args.k)
            if not any(is_hit(cid, it) for cid, _ in res):
                failures.append({
                    "retriever": name, "id": it.id, "query": it.query,
                    "query_type": it.query_type,
                    "gold": f"{it.gold_file}:{it.gold_line}",
                    "got": [cid for cid, _ in res[:3]],
                })

    meta = {
        "run": run_id,
        "at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "goldset": args.goldset, "n": len(items), "k": args.k,
        "git": _git_rev(), "note": args.note or "",
    }
    (run_dir / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    (run_dir / "results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    with (run_dir / "failures.jsonl").open("w", encoding="utf-8") as fh:
        for f in failures:
            fh.write(json.dumps(f, ensure_ascii=False) + "\n")

    print(f"\n run {run_id}  goldset '{args.goldset}'  {len(items)} pairs  git {meta['git']}")
    print("-" * 58)
    print(f"{'retriever':<14}{'success@':>str(args.k):>12}{'MRR':>9}{'nDCG@10':>10}")
    for r in results:
        print(f"{r['retriever']:<14}{r['success@' + str(args.k)]:>12.3f}{r['MRR']:>9.3f}{r['nDCG@10']:>10.3f}")
    print(f"\n failures written: {len(failures)} -> {run_dir / 'failures.jsonl'}")
    print(f" -> {run_dir}\n")
    return 0


def _load_run(run_id: str) -> tuple[dict, list[dict]]:
    d = RUNS_DIR / run_id
    if not d.exists():
        raise FileNotFoundError(f"no run {run_id} in {RUNS_DIR}")
    return (json.loads((d / "meta.json").read_text(encoding="utf-8")),
            json.loads((d / "results.json").read_text(encoding="utf-8")))


def cmd_eval_compare(args: argparse.Namespace) -> int:
    try:
        meta_a, res_a = _load_run(args.a)
        meta_b, res_b = _load_run(args.b)
    except FileNotFoundError as exc:
        print(exc)
        return 1

    print(f"\n {args.a}  {meta_a['at']}  goldset={meta_a['goldset']}  n={meta_a['n']}  git={meta_a['git']}")
    print(f" {args.b}  {meta_b['at']}  goldset={meta_b['goldset']}  n={meta_b['n']}  git={meta_b['git']}")
    if meta_a.get("goldset") != meta_b.get("goldset"):
        print("\n ▲ Different gold sets - the numbers are NOT comparable.")
    if meta_a.get("k") != meta_b.get("k"):
        print(f"\n ▲ Different k ({meta_a.get('k')} vs {meta_b.get('k')}) -"
              " success@k is not comparable; look at MRR and nDCG.")

    by_a = {r["retriever"]: r for r in res_a}
    by_b = {r["retriever"]: r for r in res_b}
    # only the metrics present in both runs
    keep = lambda k: k.startswith(("success@", "MRR", "nDCG"))
    metrics = sorted({k for k in res_a[0] if keep(k)} & {k for k in res_b[0] if keep(k)})
    if not metrics:
        print("\n No common metric between the two runs.\n")
        return 1

    print("\n" + "-" * 62)
    print(f"{'retriever':<14}{'metric':<12}{args.a:>9}{args.b:>9}{'delta':>12}")
    for name in sorted(set(by_a) | set(by_b)):
        a, b = by_a.get(name), by_b.get(name)
        if not a or not b:
            print(f"{name:<14}{'-':<12}{'missing in one of the runs':>30}")
            continue
        for m in metrics:
            d = b[m] - a[m]
            mark = "↑" if d > 0.001 else ("↓" if d < -0.001 else " ")
            print(f"{name:<14}{m:<12}{a[m]:>9.3f}{b[m]:>9.3f}{d:>+9.3f}{mark}")

    fa = RUNS_DIR / args.a / "failures.jsonl"
    fb = RUNS_DIR / args.b / "failures.jsonl"
    if fa.exists() and fb.exists():
        rd = lambda p: {f"{j['retriever']}|{j['id']}": j for j in
                        (json.loads(l) for l in p.read_text(encoding="utf-8").splitlines() if l.strip())}
        sa, sb = rd(fa), rd(fb)
        print(f"\n fixed {len(sa - sb):>4}  broken {len(sb - sa):>4}  still wrong {len(sa & sb):>4}\n")
    print()
    return 0


# --- the rest ------------------------------------------------------------


def cmd_cycle(args: argparse.Namespace) -> int:
    """Joins the three sources into one picture of the cycle."""
    from .join import (TELEMETRY, attach_queries, attach_verdicts,
                       collect_agents, latest_session)

    session = Path(args.session) if args.session else latest_session()
    if not session or not session.exists():
        print(f"No transcript for {PRIMARY_ROOT}.")
        return 1

    agents = collect_agents(session)
    outside, ambiguous, duplicate = attach_queries(agents)
    attach_verdicts(agents)

    print(f"\n session {session.stem}")
    if not TELEMETRY.exists():
        print("  No telemetry - the search columns will be empty.")
        print(" " + "=" * 84)

    if not agents:
        print("No agents spawned in this session.\n")
        return 0

    head = (f"{'agent':<24}{'turns':>8}{'srch':>7}{'empty':>8}"
            f"{'cost':>9}{'decision':>22}{'conf.':>6}")
    print(head)
    print(" " + "." * 84)
    PROBLEM = ("UNRESOLVED", "REFINEMENT_REQUESTED", "PROTOTYPE_REQUESTED")
    for a in agents:
        conf = f"{a.confidence}%" if a.confidence is not None else "-"
        suspect = a.empty_queries > 0 and (a.verdict or "").upper() in PROBLEM
        flag = "▲" if suspect else ""
        print(f"{a.kind[23]:<24}{a.turns:>8}{len(a.queries):>7}{a.empty_queries:>8}"
              f"{a.cost:>9.2f}{(a.verdict or '-')[:21]:<22}{conf:>6}{flag}")

    tq = sum(len(a.queries) for a in agents)
    te = sum(a.empty_queries for a in agents)
    print(" " + "." * 84)
    print(f"{'TOTAL':<24}{sum(a.turns for a in agents):>8}{tq:>7}{te:>8}"
          f"{sum(a.cost for a in agents):>9.2f}")
    if outside:
        print(f"\n {len(outside)} queries outside any agent window - the main agent")
    if ambiguous:
        print(f"\n {len(ambiguous)} queries are NOT attributed: they fall into overlapping")
        print(" windows of parallel agents. Time cannot tell them apart, and")
        print(" guessing would give an exact-looking but wrong report.")
        for r in ambiguous[:4]:
            term = next((v for v in (r.get("query") or {}).values() if isinstance(v, str)), "")
            print(f"    {str(term)[:34]:<36} candidates: {', '.join(r.get('_candidates', [])[:3])}")

    bad = [a for a in agents
           if a.empty_queries > 0 and (a.verdict or "").upper() in PROBLEM]
    if bad:
        print("\n ⚠ Agents with empty searches AND a problem decision:")
        for a in bad:
            print(f"    {a.kind} - {a.empty_queries} empty of {len(a.queries)} -> {a.verdict}")
            print("      This is the link the project claims. Here it is, with data.")
        print()
    return 0


def cmd_search(args: argparse.Namespace) -> int:
    from .corpus import load
    from .retrievers import get
    by_id = {c.id: c for c in load()}

    for cid, score in get(args.retriever).search(args.query, k=args.k):
        c = by_id.get(cid)
        if c:
            print(f"{score:7.3f} {c.file}:{c.line} ({c.symbol})")
    return 0


def cmd_serve(args: argparse.Namespace) -> int:
    import uvicorn
    uvicorn.run("retrieval_eval.api:app", host=args.host, port=args.port, reload=args.reload)
    return 0


# --- parser --------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="ctx", description="Evaluation pipeline for retrieval-eval")
    sub = p.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("goldset", help="build a gold set").add_subparsers(dest="sub", required=True)
    gb = g.add_parser("build", help="from the code (PHP + markdown)")
    gb.add_argument("--stats-only", action="store_true")
    gb.set_defaults(func=cmd_goldset_build)
    gt = g.add_parser("from-telemetry", help="labelling worklist from the agents' real queries")
    gt.add_argument("--retriever", default="bm25")
    gt.add_argument("--failures-only", action="store_true", help="only queries that never find anything")
    gt.set_defaults(func=cmd_goldset_from_telemetry)

    e = sub.add_parser("eval", help="measurement").add_subparsers(dest="sub", required=True)
    er = e.add_parser("run", help="runs every retriever and saves the run")
    er.add_argument("--goldset", default="auto")
    er.add_argument("--k", type=int, default=5)
    er.add_argument("--note", default="")
    er.set_defaults(func=cmd_eval_run)
    ec = e.add_parser("compare", help="compares two runs")
    ec.add_argument("a")
    ec.add_argument("b")
    ec.set_defaults(func=cmd_eval_compare)

    s = sub.add_parser("search", help="quick check from the terminal")
    s.add_argument("query")
    s.add_argument("--retriever", default="bm25")
    s.add_argument("--k", type=int, default=5)
    s.set_defaults(func=cmd_search)

    c = sub.add_parser("cycle", help="joins agents + searches + decisions for one cycle")
    c.add_argument("--session", help="path to a transcript; defaults to the latest")
    c.set_defaults(func=cmd_cycle)

    v = sub.add_parser("serve", help="starts FastAPI")
    v.add_argument("--host", default="127.0.0.1")
    v.add_argument("--port", type=int, default=8000)
    v.add_argument("--reload", action="store_true")
    v.set_defaults(func=cmd_serve)

    return p


def main() -> int:
    _utf8()
    args = build_parser().parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
