# Portfolio brief: Gated Planning Framework

## One-line description
A gated AI coding workflow that retrieves project-specific evidence, structures implementation decisions, and measures retrieval quality instead of relying on prompts alone.

## The engineering problem
An AI coding agent can produce plausible code while overlooking domain rules, existing write-side patterns, schema constraints, or architectural conventions. This project organizes context gathering and review into explicit stages and provides retrieval tools over project code and business documentation.

## What is implemented
- Role-specific agent instructions for requirements extraction, gap analysis, solution research, and constraint evaluation.
- Claude Code shell hooks that gate selected workflow transitions and check review artifacts.
- An MCP server exposing business-rule search, source search, route/entity inspection, project structure, and lesson retrieval/writing.
- JSONL telemetry for retrieval calls.
- A Python evaluation package with a keyword baseline, BM25 retriever, gold-set generation, ranking metrics, run comparisons, and a FastAPI interface.
- Tests for agent/transcript/query/verdict joining. The current test suite passes in the prepared version.

## How I would demo it
1. Show a task that touches a business rule.
2. Retrieve the relevant domain rule and code evidence through MCP.
3. Show how the workflow records alternatives and requires a review artifact before creating the implementation prompt.
4. Run the retrieval test suite and show how the evaluator records missed queries.

## Honest current limitations
- The bundled business rules are fictional sample data; a real project must replace them.
- The checked-in config includes placeholder secondary/reference project paths.
- The MCP server's Node dependencies could not be installed in the preparation environment, so syntax was checked but a live MCP session was not verified here.
- Retrieval evaluation currently covers keyword and BM25, not embeddings or reranking.
- No measured claim is made that the framework improves code quality or retrieval performance. That needs a manually reviewed, frozen benchmark and repeatable experiments.

## Interview discussion points
- Why explicit gates are useful and where they become workflow friction.
- Why retrieval quality should be evaluated with a gold set instead of inferred from tool-call telemetry.
- Why generated gold-set queries can leak target symbols and overstate performance.
- How to add embeddings/hybrid retrieval and reranking without changing the evaluation contract.
- How to add tracing, cost budgets, retries, schema validation, and regression thresholds.
