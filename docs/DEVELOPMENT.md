# Development and evaluation

This page contains the setup and operating details kept out of the main README so the project overview stays quick to scan.

## Configuration

Edit `framework.config.json`. Relative paths are resolved from the configuration file. Update project roots and source directories for your environment, and replace the fictional example in `docs/BUSINESS_LOGIC.md` with verified domain rules.

Do not commit credentials, customer data, private source code, generated corpus extracts, or telemetry unless they are safe to publish.

## MCP server

```bash
cd dev-context-mcp
npm install
npm start
```

Configure Claude Code to launch `dev-context-mcp/index.js` from the expected working directory. The server reads `framework.config.json`; `FRAMEWORK_CONFIG` can point to a specific configuration file.

The MCP tools provide project-context search and source inspection. Route introspection may use PHP/Composer when available, with source scanning as a fallback.

## Retrieval evaluation CLI

From `retrieval-eval/`, activate the Python environment and install `requirements.txt` as described in the main README. Then run:

```bash
export PYTHONPATH=src
python -m retrieval_eval.cli --help
python -m retrieval_eval.cli goldset build
python -m retrieval_eval.cli eval run --note "initial baseline"
python -m retrieval_eval.cli eval compare 001 002
python -m retrieval_eval.cli serve
```

The local API documentation is available at `http://localhost:8000/docs` after starting the API.

Evaluation data is generated locally. A run stores metadata, metrics, and failure cases under `retrieval-eval/data/runs/`. The comparison command warns when the gold set or `k` differs, since those runs may not be directly comparable.

### Interpreting the results

The package currently compares keyword retrieval and BM25 using metrics such as Success@k, MRR, and nDCG. Automatically generated gold-set questions can contain code symbols that make retrieval artificially easy. Treat the automatic set as a regression aid, not proof of real-world quality. For stronger evidence, manually review a realistic set of questions and freeze it before comparing approaches.

Telemetry shows what was searched and what the system returned; it does not establish the correct answer. Human review is required to label ground truth.

## Repository checks

Run from the repository root:

```bash
# JavaScript syntax
for f in dev-context-mcp/index.js dev-context-mcp/lib/*.js; do node --check "$f" || exit 1; done

# Shell syntax
find . -name '*.sh' -print0 | xargs -0 -n1 bash -n

# Python tests
cd retrieval-eval
PYTHONPATH=src python -m pytest -q
```

The MCP runtime check requires installing npm dependencies; the Python tests require the dependencies listed in `retrieval-eval/requirements.txt`.

## Known limitations

- MCP retrieval is currently keyword-based; the Python evaluation package compares keyword and BM25. Embeddings, vector search, and reranking are not included.
- Source scanning is heuristic and does not replace a full PHP AST parser or framework-native route metadata in a configured application.
- Shell gates verify the presence and consistency of workflow artifacts, not the factual correctness of an AI-generated decision.
- The checked-in configuration and sample domain content are scaffolding. Validate the framework against a target repository before relying on it.
