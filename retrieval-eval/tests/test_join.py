"""Tests for joining agent queries -> decision.

Real-shaped transcripts are built here, because Claude Code deletes transcripts
older than 30 days, so real framework runs cannot be relied on as fixtures.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from retrieval_eval import join  # noqa: E402

MCP = join.MCP_PREFIX


def _write(path: Path, records: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(r) for r in records) + "\n", encoding="utf-8")


def _spawn(tool_id: str, agent_id: str, kind: str, solution: str | None, ts: str) -> list[dict]:
    prompt = f"Solution: {solution}\nConstraint: something" if solution else "do something"
    return [
        {"type": "assistant", "timestamp": ts, "message": {"model": "claude-sonnet-5", "usage": {},
         "content": [{"type": "tool_use", "id": tool_id, "name": "Agent",
         "input": {"subagent_type": kind, "description": "d", "prompt": prompt}}]}},
        {"type": "user", "timestamp": ts, "toolUseResult": {"agentId": agent_id},
         "message": {"content": [{"type": "tool_result", "tool_use_id": tool_id, "content": "ok"}]}},
    ]


def _agent_file(mcp_calls: list[tuple[str, dict, object]], ts: str) -> list[dict]:
    """mcp_calls: (tool, input, result) - result is what the tool returns."""
    out: list[dict] = []
    for i, (tool, inp, result) in enumerate(mcp_calls):
        tid = f"tool_u-{i}"
        out.append({"type": "assistant", "timestamp": ts,
                    "message": {"model": "claude-sonnet-5",
                    "usage": {"input_tokens": 20, "output_tokens": 5},
                    "content": [{"type": "tool_use", "id": tid,
                    "name": f"{MCP}{tool}", "input": inp}]}})
        out.append({"type": "user", "timestamp": ts,
                    "message": {"content": [{"type": "tool_result", "tool_use_id": tid,
                    "content": json.dumps(result)}]}})
    return out


@pytest.fixture()
def session(tmp_path, monkeypatch):
    """Assembles a main transcript + two subagent files."""
    main = tmp_path / "sess.jsonl"
    subs = tmp_path / "sess" / "subagents"

    _write(main, [
        *_spawn("t1", "aaa", "constraint-evaluator", "AuditLog Schema Design", "2026-09-23T10:00:00Z"),
        *_spawn("t2", "bbb", "solution-researcher", "AuditLog Subscriber", "2026-09-23T10:00:01Z"),
    ])

    # agent A: 3 searches, 2 empty
    _write(subs / "agent-aaa.jsonl", _agent_file([
        ("search_business_logic", {"query": "refund"}, []),
        ("search_business_logic", {"query": "chargeback"}, []),
        ("search_code", {"pattern": "StoreService", "project": "primary"}, [{"f": 1}, {"f": 2}]),
    ], "2026-09-23T10:00:05Z"))

    # agent B: 1 search, found
    # window deliberately overlaps agent A - exactly the parallel-agents case
    _write(subs / "agent-bbb.jsonl", _agent_file([
        ("get_lessons", {"query": "doctrine"}, [{"lesson": "x"}]),
    ], "2026-09-23T10:00:05Z"))

    research = tmp_path / "solutions-research.md"
    research.write_text(
        "## Solution: AuditLog Schema Design\n"
        "**Confidence after research:** 72%\n"
        "**Evaluator verdict:** UNRESOLVED\n"
        "## Solution: AuditLog Subscriber\n"
        "**Confidence after research:** 94%\n"
        "**Evaluator verdict:** AUTO-SELECTED EventSubscriber\n",
        encoding="utf-8"
    )

    monkeypatch.setattr(join, "FRAMEWORK", tmp_path)
    monkeypatch.setattr(join, "TELEMETRY", tmp_path / "mcp-queries.jsonl")
    return main


def test_agents_and_solutions_extracted(session):
    agents = join.collect_agents(session)
    assert [a.kind for a in agents] == ["constraint-evaluator", "solution-researcher"]
    assert [a.solution for a in agents] == ["AuditLog Schema Design", "AuditLog Subscriber"]
    assert [a.agent_id for a in agents] == ["aaa", "bbb"]


def test_queries_come_from_the_agents_own_transcript(session):
    a, b = join.collect_agents(session)
    assert len(a.queries) == 3
    assert a.empty_queries == 2  # refund and chargeback return []
    assert len(b.queries) == 1
    assert b.empty_queries == 0


def test_verdicts_matched_by_solution_title(session):
    agents = join.collect_agents(session)
    join.attach_verdicts(agents)
    a, b = agents
    assert (a.verdict, a.confidence) == ("UNRESOLVED", 72)
    assert (b.verdict, b.confidence) == ("AUTO-SELECTED", 94)


def test_overlapping_windows_are_not_guessed(session, tmp_path):
    """Telemetry that falls into overlapping windows is attributed to no one."""
    agents = join.collect_agents(session)
    _write(tmp_path / "mcp-queries.jsonl", [
        {"ts": "2026-09-23T10:00:05Z", "tool": "search_code",
         "query": {"pattern": "x"}, "results": 0, "empty": True},  # inside both
        {"ts": "2020-01-01T00:00:00Z", "tool": "get_lessons",
         "query": {"query": "far away"}, "results": 0, "empty": True},  # outside all
    ])
    outside, ambiguous, duplicate = join.attach_queries(agents)
    assert len(ambiguous) == 1
    assert len(outside) == 1
    # attribution from the transcripts is unaffected
    assert sum(len(a.queries) for a in agents) == 4


@pytest.mark.parametrize("payload, expected", [
    ((), 0),
    ({"a": 1, "b": 2}, 2),
    ({"error": "nothing"}, 0),
    ({"results": [1, 2, 3]}, 3),
    ({"x": 1, "y": 2}, 2),
])
def test_result_counting(payload, expected):
    content = [{"type": "text", "text": json.dumps(payload)}]
    assert join._count_result(content) == expected
