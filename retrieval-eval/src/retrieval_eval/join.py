"""Connects the three sources that do not talk to each other today.

1. Claude Code transcripts -> which agent, when, how much it cost
2. mcp-queries.jsonl -> what it searched for and whether it found it
3. solutions-research.md -> which decision it produced in the end

Agent queries: each subagent's MCP calls are in ITS OWN transcript, so the
attribution is exact. Joining by time does not work - the framework runs agents
in parallel and their windows overlap.

Agent decision: the prompt the agent was spawned with contains
'Solution: <title>', which is also found in solutions-research.md.

The telemetry (mcp-queries.jsonl) remains for the queries of the MAIN agent,
which has no separate transcript.

Nothing is changed in the other systems. This module only reads.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

from .config import FRAMEWORK_DIR, TELEMETRY_PATH, TRANSCRIPTS_DIR

TRANSCRIPTS = TRANSCRIPTS_DIR
FRAMEWORK = FRAMEWORK_DIR
TELEMETRY = TELEMETRY_PATH

PRICE = {
    "claude-opus-5": (5, 25), "claude-opus-4-8": (5, 25),
    "claude-sonnet-5": (2, 10), "claude-sonnet-4-6": (3, 15),
    "claude-haiku-4-5": (1, 5), "claude-fable-5-1": (10, 50),
}

MCP_PREFIX = "mcp__dev-context__"


def _count_result(content) -> int:
    """How many results an MCP tool returned. Its output is JSON text."""
    if isinstance(content, list):
        text = "".join(b.get("text", "") for b in content if isinstance(b, dict))
    elif isinstance(content, str):
        text = content
    else:
        return 0
    text = text.strip()
    if not text:
        return 0
    try:
        value = json.loads(text)
    except json.JSONDecodeError:
        return 1 if text else 0
    if isinstance(value, list):
        return len(value)
    if isinstance(value, dict):
        if value.get("error"):
            return 0
        for key in ("results", "matches", "fields", "routes", "chunks", "lessons"):
            if isinstance(value.get(key), list):
                return len(value[key])
        return len(value)
    return 1 if value else 0


def _cost(model: str | None, u: dict) -> float:
    pin, pout = next((v for k, v in PRICE.items() if (model or "").startswith(k)), (5, 25))
    return (u.get("input_tokens", 0) * pin
            + u.get("cache_creation_input_tokens", 0) * pin * 1.25
            + u.get("cache_read_input_tokens", 0) * pin * 0.1
            + u.get("output_tokens", 0) * pout) / 1e6


def _ts(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _jsonl(path: Path) -> list[dict]:
    out = []
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.strip():
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return out


@dataclass
class AgentRun:
    kind: str                                   # subagent_type
    description: str
    solution: str | None                        # the title from the prompt, if any
    agent_id: str | None = None
    start: datetime | None = None
    end: datetime | None = None
    cost: float = 0.0
    turns: int = 0
    queries: list[dict] = field(default_factory=list)
    verdict: str | None = None
    confidence: int | None = None

    @property
    def empty_queries(self) -> int:
        return sum(1 for q in self.queries if q.get("empty"))


RE_SOLUTION = re.compile(r"Solution:\s*(?:##\s*Solution:\s*)?(.+)")


def _solution_from_prompt(prompt: str) -> str | None:
    for line in (prompt or "").splitlines():
        m = RE_SOLUTION.search(line.strip())
        if m:
            title = m.group(1).strip().strip("[]\'\"")
            return title or None
    return None


def latest_session() -> Path | None:
    if not TRANSCRIPTS.exists():
        return None
    files = sorted(TRANSCRIPTS.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)
    return files[0] if files else None


def collect_agents(session_file: Path) -> list[AgentRun]:
    main = _jsonl(session_file)
    spawns: dict[str, AgentRun] = {}             # tool_use id -> AgentRun
    order: list[str] = []

    for rec in main:
        content = (rec.get("message") or {}).get("content")
        if not isinstance(content, list):
            continue
        for block in content:
            if block.get("type") == "tool_use" and block.get("name") in ("Agent", "Task"):
                inp = block.get("input") or {}
                run = AgentRun(
                    kind=inp.get("subagent_type") or "unknown",
                    description=inp.get("description") or "",
                    solution=_solution_from_prompt(inp.get("prompt", "")),
                    agent_id=None,
                )
                spawns[block["id"]] = run
                order.append(block["id"])
            elif block.get("type") == "tool_result":
                # toolUseResult is sometimes an object, sometimes a string (e.g. Bash output)
                tur = rec.get("toolUseResult")
                agent_id = tur.get("agentId") if isinstance(tur, dict) else None
                tid = block.get("tool_use_id")
                if agent_id and tid in spawns:
                    spawns[tid].agent_id = agent_id

    sub_dir = session_file.parent / session_file.stem / "subagents"
    for run in spawns.values():
        if not run.agent_id:
            continue
        f = sub_dir / f"agent-{run.agent_id}.jsonl"
        pending: dict[str, dict] = {}
        for rec in _jsonl(f):
            t = _ts(rec.get("timestamp"))
            if t:
                run.start = t if run.start is None or t < run.start else run.start
                run.end = t if run.end is None or t > run.end else run.end
            if rec.get("type") == "assistant" and rec.get("message"):
                run.turns += 1
                run.cost += _cost(rec["message"].get("model"), rec["message"].get("usage") or {})

            content = (rec.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            for block in content:
                # The agent's MCP calls are in ITS transcript - this is exact
                # attribution, unlike joining by time, which is ambiguous for parallel agents.
                if block.get("type") == "tool_use" and str(block.get("name", "")).startswith(MCP_PREFIX):
                    inp = block.get("input") or {}
                    q = {
                        "tool": str(block["name"])[len(MCP_PREFIX):],
                        "query": {k: v for k, v in inp.items() if isinstance(v, (str, int))},
                        "ts": rec.get("timestamp"),
                        "source": "transcript",
                    }
                    pending[block["id"]] = q
                    run.queries.append(q)
                elif block.get("type") == "tool_result" and block.get("tool_use_id") in pending:
                    q = pending.pop(block["tool_use_id"])
                    q["results"] = _count_result(block.get("content"))
                    q["empty"] = q["results"] == 0

        for q in pending.values():                  # no result in the transcript
            q.setdefault("results", None)
            q.setdefault("empty", False)

    return [spawns[i] for i in order]


def attach_queries(agents: list[AgentRun]) -> tuple[list[dict], list[dict], list[dict]]:
    """Attributes each telemetry query to the agent whose window it falls into.

    The framework runs researchers and evaluators IN PARALLEL, so their windows
    overlap. A query that falls into more than one window is NOT attributed - it
    is returned as ambiguous. Silently picking the first matching agent would
    produce an exact-looking but wrong report.

    Returns (outside any window, ambiguous, duplicates).
    """
    rows = _jsonl(TELEMETRY)
    outside: list[dict] = []
    ambiguous: list[dict] = []
    duplicate: list[dict] = []
    windowed = [a for a in agents if a.start and a.end]
    for r in rows:
        t = _ts(r.get("ts"))
        if not t:
            outside.append(r)
            continue
        owners = [a for a in windowed if a.start <= t <= a.end]
        if not owners:
            outside.append(r)               # the main agent
            continue
        # Subagent queries have already been read exactly from their own
        # transcripts. Telemetry inside one agent's window is a duplicate;
        # in overlapping windows it cannot be decided whose it is. Neither is
        # attributed, but neither disappears silently.
        r["_candidates"] = [a.kind for a in owners]
        (ambiguous if len(owners) > 1 else duplicate).append(r)
    return outside, ambiguous, duplicate


RE_BLOCK = re.compile(r"^##\s*Solution:\s*(.+)$", re.MULTILINE)
RE_VERDICT = re.compile(r"Evaluator verdict:\*{0,2}\s*([A-Z_-]+)")
RE_CONF = re.compile(r"Confidence after research:\*{0,2}\s*(\d+)\s*%")


def attach_verdicts(agents: list[AgentRun]) -> dict[str, tuple[str | None, int | None]]:
    path = FRAMEWORK / "solutions-research.md"
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8", errors="replace")
    marks = [(m.group(1).strip(), m.start()) for m in RE_BLOCK.finditer(text)]
    blocks: dict[str, tuple[str | None, int | None]] = {}
    for i, (title, pos) in enumerate(marks):
        end = marks[i + 1][1] if i + 1 < len(marks) else len(text)
        body = text[pos:end]
        v = RE_VERDICT.findall(body)
        c = RE_CONF.findall(body)
        blocks[title] = (v[-1] if v else None, int(c[-1]) if c else None)

    for a in agents:
        if not a.solution:
            continue
        key = next((t for t in blocks if t.lower() == a.solution.lower()), None)
        if key is None:
            key = next((t for t in blocks if a.solution.lower() in t.lower()
                        or t.lower() in a.solution.lower()), None)
        if key:
            a.verdict, a.confidence = blocks[key]
    return blocks
