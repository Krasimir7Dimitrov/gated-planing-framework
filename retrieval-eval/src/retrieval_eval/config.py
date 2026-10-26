"""Paths and settings. Corpus locations come from framework.config.json - the same
file the dev-context MCP server reads, so both search the same code and docs.

The config is looked up in this order:
1. FRAMEWORK_CONFIG (env) - absolute or relative path to the file
2. framework.config.json in the current folder
3. framework.config.json in the folder above retrieval-eval/
Relative paths in the config are resolved against the folder that contains the file.
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = PROJECT_ROOT / "data"
GOLDSET_DIR = DATA_DIR / "goldset"


def _find_config() -> Path:
    env = os.environ.get("FRAMEWORK_CONFIG")
    candidates = [Path(env).resolve()] if env else []
    candidates += [Path.cwd() / "framework.config.json",
                   PROJECT_ROOT.parent / "framework.config.json"]
    for c in candidates:
        if c.is_file():
            return c
    raise FileNotFoundError(
        "framework.config.json not found. Looked in: " + ", ".join(str(c) for c in candidates))


CONFIG_PATH = _find_config()
CONFIG_DIR = CONFIG_PATH.parent
_cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def _path(p: str) -> Path:
    path = Path(p)
    return path if path.is_absolute() else (CONFIG_DIR / path).resolve()


# The corpus the framework actually searches - mirrors projects.*.srcDirs used by
# the MCP server's search_code.
CORPORA: dict[str, dict] = {
    name: {"root": _path(p.get("root", ".")), "src_dirs": p.get("srcDirs", ["src"])}
    for name, p in (_cfg.get("projects") or {}).items()
}
if "primary" not in CORPORA:
    raise ValueError(f"{CONFIG_PATH}: projects.primary is required")

PRIMARY_ROOT: Path = CORPORA["primary"]["root"]

DOC_FILES: list[Path] = [
    _path(_cfg.get("businessLogicPath", "docs/BUSINESS_LOGIC.md")),
    PRIMARY_ROOT / "CLAUDE.md",
    PRIMARY_ROOT / ".claude" / "FRAMEWORK.md",
]

# The framework's working folder (solutions-research.md lives here) and the MCP telemetry.
FRAMEWORK_DIR = PRIMARY_ROOT / ".claude"
TELEMETRY_PATH = _path(_cfg.get("telemetryPath", ".claude/metrics/mcp-queries.jsonl"))

# Claude Code stores transcripts per project folder, with every non-alphanumeric
# character of the path replaced by "-" (same rule as run-report.mjs).
TRANSCRIPTS_DIR = Path.home() / ".claude" / "projects" / re.sub(r"[^a-zA-Z0-9]", "-", str(PRIMARY_ROOT))

EXCLUDE_PARTS = {"vendor", "node_modules", "var", "public", "migrations", "Tests", "tests"}

# Docblocks that carry no information - counted, but never turned into queries
TRIVIAL_DOC_PATTERNS = (
    r"^\s*@inheritdoc\s*$",
    r"^\s*(get|set|is|has)\s+\w+\.?\s*$",
    r"^\s*constructor\s*\.?\s*$",
    r"^\s*@var\s+",
    r"^\s*@see\s+",
)

MIN_QUERY_WORDS = 4
MIN_QUERY_CHARS = 20