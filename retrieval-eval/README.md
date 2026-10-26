# retrieval-eval

Retrieval layer for the Pre-Implementation Protocol framework.

The `dev-context` MCP server searches `BUSINESS_LOGIC.md` and the code by **counting how many of the query's words occur in a chunk** (`score += 1`). That had never been measured. This package measures it, and is the place to replace it with something better.

It reads the same `framework.config.json` as the MCP server, so both search the same code and documents:

| Config key | Used for |
|---|---|
| `projects.*.root` + `srcDirs` | PHP corpus (every configured project) |
| `businessLogicPath` | documentation corpus together with `CLAUDE.md` and `.claude/FRAMEWORK.md` of the primary project |
| `telemetryPath` | `ctx goldset from-telemetry` and `ctx cycle` |

The config is found via `FRAMEWORK_CONFIG`, then `framework.config.json` in the current folder, then the folder above `retrieval-eval/`.

## CLI

Six commands, one file (`cli.py`), `argparse` only. State is JSON files in `data/runs/` - no database, no config file of its own, no orchestrator.

```bash
pip install fastapi "uvicorn[standard]" rank_bm25
export PYTHONPATH=src
alias ctx="python -m retrieval_eval.cli"

ctx goldset build                # gold set from your code
ctx goldset from-telemetry       # labelling worklist from the agents' real queries
ctx eval run --note "baseline"   # every retriever + data/runs/NNN/
ctx eval compare 001 002         # what improved, what broke
ctx search "store payout account"# quick check
ctx cycle                        # agents + searches + decisions for the latest cycle
ctx serve                        # starts FastAPI
```

**The gold set is generated with `ctx goldset build` on your project.** Nothing in `data/` is shipped - it is created locally and ignored by git.

### Artifacts of one run

```
data/runs/001/
  meta.json      when, which gold set, k, git rev, note
  results.json   the metrics
  failures.jsonl the queries the retriever misses + the most useful part
```

`eval compare` compares only metrics present in both runs, and warns when the gold set or `k` differ - otherwise it would compare numbers that are not comparable. Re-running with the same inputs gives exactly zero differences (`fixed 0 broken 0`); that is the check that there are no phantom deltas.

### `goldset from-telemetry` - what it does NOT do

The telemetry knows what was asked and whether it was found, but **not what the correct answer is**. So the command does not invent gold - it writes a list with empty `gold_file` / `gold_line` fields for a human to fill in, plus the current candidates as a hint. Anything else would be a set that measures itself.

## API

`ctx serve`, then http://localhost:8000/docs

| Endpoint | What it does |
|---|---|
| `GET /health` | number of chunks, available retrievers, gold set size |
| `GET /search?q=...&retriever=bm25&k=5` | searches the PHP code (all configured projects) and the docs |
| `GET /eval?goldset=auto` | runs the gold set against every retriever and returns the metrics |

## How the gold set is built

Pairs of (query -> correct `file:line`), extracted from your PHP files and markdown documents using the CodeSearchNet method: a symbol's description is the query, its declaration is the correct answer.

| Type | Query | Correct answer |
|---|---|---|
| `method_doc` / `class_doc` | the docblock, cleaned to prose | the method / class declaration |
| `orm_column` | "Which field of Order stores status and what type is it (integer)?" | the Doctrine column property |
| `orm_relation` | "What is the ManyToOne relation between AuditLog and Store through the field store?" | the Doctrine relation property |
| `route` | "Which controller handles the route /audit-history (name: get_audit_history)?" | the controller action |
| `doc_section` | the header path, e.g., "Customer Groups > Import Existing" | the markdown section |

Rejected while building: trivial docblocks (`@inheritdoc`, `get id`), ambiguous queries (one query -> different answers), thin sections and generic top-level headers. `ctx goldset build` prints the counts for your project.

## Reading the numbers

1. **The automatic set is too easy.** Its queries contain the symbols' own names (`AuditLog`, `storeId`), so success@k tends to hit the ceiling for every retriever. The informative metric is **MRR** - whether the correct answer is ranked first, not merely present.
2. **A few hundred pairs** are enough to track regressions, but not to support claims like "X beats Y by 12%".
3. The next step is therefore a **hand-written set of ~40 questions**, frozen before the next retriever is built. The automatic set is the track; the hand-written one is the truth.

## Structure

```
src/retrieval_eval/
  config.py       corpus paths from framework.config.json
  corpus.py       PHP + markdown -> search chunks
  retrievers.py   keyword (the current algorithm) and BM25
  evaluate.py     success@k, MRR, nDCG + running the gold set
  join.py         transcripts + telemetry + solutions-research.md -> one cycle
  cli.py          ctx
  api.py          FastAPI
  goldset/
    php.py        pair extraction from PHP
    markdown.py   chunking by header path (as in the MCP server)
    build.py      builds data/goldset/auto.jsonl
tests/
  test_join.py    agent -> queries -> decision joining
```

Run the tests with `python -m pytest tests` from this folder.

## Next

- [ ] 1b - hand-written gold set, 40 questions
- [ ] 2 - embeddings + vector store + hybrid + reranker, against the same metrics
- [ ] 3 - Docker, CI (eval fails on regression), the MCP server switches to this
