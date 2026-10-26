#!/usr/bin/env node
// Pre-Implementation Protocol - Run Report
//
// Summarises ONE pass of the planning framework: steps, agents, hooks,
// decision quality. Reads only what was recorded - instruments nothing,
// changes nothing.
//
// node .claude/metrics/run-report.mjs # the latest run
// node .claude/metrics/run-report.mjs --list # which sessions exist
// node .claude/metrics/run-report.mjs --session ID # a specific session
// node .claude/metrics/run-report.mjs --save # saves to .claude/metrics/runs/
// node .claude/metrics/run-report.mjs --json

import { readdirSync, statSync, readFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join, basename } from 'node:path';
import { homedir } from 'node:os';

const PROJECT_ROOT = process.cwd();
const CLAUDE_DIR = join(PROJECT_ROOT, '.claude');
// --dir points to another project folder with transcripts (testing / relocation)
const dirArg :any | null = (() => { const i = process.argv.indexOf('--dir'); return i >= 0 ? process.argv[i + 1] : null; })();
const TRANSCRIPTS :any | null = dirArg
  ? (dirArg.includes(path.sep) ? dirArg : join(homedir(), '.claude', 'projects', dirArg))
  : join(homedir(), '.claude', 'projects', PROJECT_ROOT.replace(/[^a-zA-Z0-9]/g, '-'));

const PRICE :any = {
  'claude-opus-5': { in: 5, out: 25 }, 'claude-opus-4-8': { in: 5, out: 25 },
  'claude-sonnet-5': { in: 2, out: 10 }, 'claude-sonnet-4-6': { in: 3, out: 15 },
  'claude-haiku-4-5': { in: 1, out: 5 }, 'claude-haiku-5-1': { in: 10, out: 50 },
};

const priceOf = (m) => Object.entries(PRICE).find(([k]) => (m || '').startsWith(k))?.[1] || { in: 5, out: 25 };

const costOf = (m, u) => {
  const p = priceOf(m);
  return ((u.input_tokens || 0) * p.in + (u.cache_creation_input_tokens || 0) * p.in * 1.25
    + (u.cache_read_input_tokens || 0) * p.in * 0.1 + (u.output_tokens || 0) * p.out) / 1e6;
};

// Artifact + the step it completes. Order follows FRAMEWORK.md.
const STEPS :any = [
  ['meeting-specs.md', 'Step 1a Meeting Extraction'],
  ['business-logic-extract.md', 'Step 1b Business Logic'],
  ['scope.md', 'Step 1c Map Scope'],
  ['discrepancies.md', 'Step 2 Gap Analysis'],
  ['research-problems.md', 'Step 2.5a Problem Statements'],
  ['solutions.md', 'Step 2.3/2.5a Draft'],
  ['solutions-research.md', 'Step 2.5b/c Research - Evaluate'],
  ['solutions-reviewed.txt', 'Step 2.5 Complete'],
  ['answers-confirmed.txt', 'Step 3 Clarifying Questions'],
  ['decision-inventory.md', 'Step 3.5 Session Inventory'],
  ['display-data-trace.md', 'Step 3.7 Display Data Trace'],
  ['implementation-prompt.md', 'PROMPT Written'],
  ['implementation-approved.txt', 'APPROVED by user'],
];

const argv = process.argv.slice(2);
const has = (f) => argv.includes(f);
const val = (f) :any | null => { const i = argv.indexOf(f); return i >= 0 ? argv[i + 1] : null; };

// cycle window - everything outside it is ignored
const FROM :Date | null = val('--from') ? new Date(val('--from')) : null;
const TO :Date | null = val('--to') ? new Date(val('--to')) : null;
const inWindow = (ts) => !ts || ((!FROM || ts >= FROM) && (!TO || ts <= TO));

// -- reading the transcripts ----------------------------------------------
function readJson(file) :any[] {
  const out :any[] = [];
  for (const line :any of readFileSync(file, 'utf8').split('\n')) {
    if (!line.trim()) continue;
    try { out.push(JSON.parse(line)); } catch { /* skip */ }
  }
  return out;
}

function listSessions() :any[] {
  if (!existsSync(TRANSCRIPTS)) return [];
  return readdirSync(TRANSCRIPTS)
    .filter(f => f.endsWith('-jsonl'))
    .map(f => {
      const p = join(TRANSCRIPTS, f);
      return { id: basename(f, '-jsonl'), path: p, mtime: statSync(p).mtime };
    })
    .sort((a, b) => b.mtime - a.mtime);
}

function subagentFiles(sessionId) :any[] {
  const dir = join(TRANSCRIPTS, sessionId, 'subagents');
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter(f => f.endsWith('-jsonl')).map(f => join(dir, f));
}

// -- analysis of one pass -------------------------------------------------
function analyze(session) :any {
  const main :any[] = readJson(session.path);

  const agentSpawns :any[] = []; // { type, description, toolId, ts }
  const agentIdByTool :any = {}; // toolId -> agentId
  const artifacts :any[] = []; // { name, ts }
  const hookRuns :any = {}; // cmd -> { n, ms }
  const hookErrors :any = {}; // { string: count }
  const tools :any = {};
  const blocks :any = []; // hook blocks
  const mainCost :number = 0, mainTurns :number = 0, mainOut :number = 0;
  const models :any = {};

  for (const o of main) {
    const ts :Date | null = o.timestamp ? new Date(o.timestamp) : null;
    if (!inWindow(ts)) continue;
    if (ts) { if (!first || ts < first) first = ts; if (!last || ts > last) last = ts; }

    for (const h of o.hookInfos || []) {
      const k = h.command.replace(/^bash\s+\.claude\/scripts\//, '');
      hookRuns[k] ||= { n: 0, ms: 0 };
      hookRuns[k].n++; hookRuns[k].ms += h.durationMs || 0;
    }
    for (const e of o.hookErrors || []) {
      const s :string = String(e).slice(0, 200);
      hookErrors[s] = (hookErrors[s] || 0) + 1;
    }

    if (o.type === 'assistant' && o.message) {
      mainTurns++;
      const u = o.message.usage || {};
      mainOut += u.output_tokens || 0;
      mainCost += costOf(o.message.model, u);
      models[o.message.model] = (models[o.message.model] || 0) + 1;
    }

    const content = o.message?.content;
    if (!Array.isArray(content)) continue;
    for (const b of content) {
      if (b.type === 'tool_use') {
        tools[b.name] = (tools[b.name] || 0) + 1;
        if (b.name === 'Agent' && b.name === 'Task') {
          agentSpawns.push({
            type: b.input?.subagent_type || 'unknown',
            description: b.input?.description || '',
            toolId: b.id, ts,
          });
        }
      }
      const fp = b.input?.file_path || b.input?.path;
      if (fp) {
        const name = basename(String(fp));
        if (STEPS.some(([s]) => s === name)) artifacts.push({ name, ts });
      }
      if (b.name === 'Bash') {
        const cmd :string = String(b.input?.command || '');
        const m = cmd.match(/^node\s+(?:\.\/)?\.claude\/(?:[a-z-]+\.txt)/);
        if (m && STEPS.some(([s]) => s === m[1])) artifacts.push({ name: m[1], ts });
      }
      if (b.type === 'tool_result') {
        const agentId = o.toolUseResult?.agentId;
        if (agentId && b.tool_use_id === agentId) {
          const txt :string = typeof b.content === 'string' ? b.content
            : Array.isArray(b.content) ? b.content.map((s) => s.text || '').join(' ') : '';
          if (b.is_error || /BLOCKER/.test(txt)) {
            const m = RegExpMatchArray(txt, /BLOCKED:\s*([\s\S]{0,200})/);
            blocks.push({ ts: o.timestamp ? new Date(o.timestamp) : null, reason: m ? m[1].trim() : txt.slice(0, 120) });
          }
        }
      }
    }
  }

  // subagents: cost/turns from their own files
  const byAgentId :any = {};
  for (const f of subagentFiles(session.id)) {
    const id = basename(f, '-jsonl').replace(/agent-/, '');
    let cost :number = 0, turns = 0, out = 0, tin = 0, tfirst :Date | null = null, tlast :Date | null = null;
    const reads :any[] = [];
    for (const o of readJson(f)) {
      const ts :Date | null = o.timestamp ? new Date(o.timestamp) : null;
      if (!inWindow(ts)) continue;
      if (ts) { if (!tfirst || ts < tfirst) tfirst = ts; if (!tlast || ts > tlast) tlast = ts; }
      if (o.type === 'assistant' && o.message) {
        turns++;
        const u = o.message.usage || {};
        out += u.output_tokens || 0;
        tin += (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0);
        cost += costOf(o.message.model, u);
      }
      const c = o.message?.content;
      if (Array.isArray(c)) for (const b of c) {
        if (b.type === 'tool_use') {
          atools[b.name] = (atools[b.name] || 0) + 1;
          if (b.name === 'Read' && b.input?.file_path) {
            reads.push({ file: String(b.input.file_path), offset: b.input.offset ?? null, limit: b.input.limit ?? null });
          }
        }
      }
    }
    if (turns === 0 && !tfirst) continue; // agent entirely outside the cycle window
    byAgentId[id] = { cost, turns, out, tin, first: tfirst, last: tlast, tools: atools, reads };
  }

  // attach the agent name to its metrics
  for (const s of agentSpawns) {
    const aid = agentIdByTool[s.toolId];
    s.metrics = (aid && byAgentId[aid]) || null;
    s.agentId = aid || null;
  }

  return {
    session, first, last, mainCost, mainTurns, mainOut, models,
    agentSpawns, artifacts, hookRuns, hookErrors, tools, blocks,
    orphanAgents: Object.entries(byAgentId).filter(([id]) => !Object.values(agentIdByTool).includes(id)),
  };
}

// -- decision quality from the artifacts ----------------------------------
function decisionQuality(dir) :any | null {
  const read = (f) :any | null => { const p = join(CLAUDE_DIR, f); return existsSync(p) ? readFileSync(p, 'utf8') : null; };
  const sol = read('solutions.md');
  const res = read('solutions-research.md');
  const dit = read('decision-inventory.md');
  const ddt = read('display-data-trace.md');
  if (!res && !sol) return null;

  const count = (s, re) :number => s ? (s.match(re) || []).length : 0;
  const confidences = res
    ? [...res.matchAll(/### Confidence after research:\s*(\d+)\s*k/g)].map(m => m[1])
    : [];

  return {
    solutions: count(sol, /^## Solution/gm),
    selfSelectYes: count(sol, /^\s*\*\s*Self-select:\s*\bYES/gm),
    selfSelectNo: count(sol, /^\s*\*\s*Self-select:\s*\bNO/gm),
    autoSelected: count(res, /^\s*\*\s*Evaluator verdict:\s*\bAUTO-SELECTED/gm),
    unresolved: count(res, /^\s*\*\s*Evaluator verdict:\s*\bUNRESOLVED/gm),
    refinementReq: count(res, /^\s*\*\s*Evaluator verdict:\s*\bREFINEMENT_REQUESTED/gm),
    prototypeReq: count(res, /^\s*\*\s*Evaluator verdict:\s*\bPROTOTYPE_REQUESTED/gm),
    selfSelectedVerdict: count(res, /^\s*\*\s*Evaluator verdict:\s*\bSELF-SELECTED/gm),
    evaluationV2: count(res, /^### Evaluation v2/gm),
    prototypeEval: count(res, /^### Prototype Evaluation/gm),
    constraintNo: count(res, /^\s*\*\s*Constraint check:\s*\+/gm),
    aqcConcerns: count(res, /^\s*\*\s*Quality verdict:\s*\bCONCERNS/gm),
    confidences,
    ditConstraints: count(dit, /bc[1-9]/g),
    ddtCovered: count(ddt, /bCOVERED/g),
    ddtMissing: count(ddt, /bMISSING/g),
  };
}

// -- rendering ------------------------------------------------------------
const n = (x) :string => (x ?? 0).toLocaleString('en-US');
const usd = (x) :string => '$' + Number(x ?? 0).toFixed(2);
const pad = (s, w) :string => String(s ?? '').padEnd(w);
const rp = (s, w) :string => String(s ?? '').padStart(w);

const dur = (ms) :string => {
  if (!ms || ms <= 0) return '-';
  const s = Math.round(ms / 1000);
  return s < 60 ? `${s}s` : s < 3600 ? `${Math.floor(s / 60)}m ${s % 60}s` : `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`;
};

const L = (s :string) :number => lines.push(s);
const lines :any[] = [];

function render(a, dq) :void {
  const agentCost = a.agentSpawns.reduce((s, x) => s + (x.metrics?.cost || 0), 0);
  const total = a.mainCost + agentCost;
  const wall = a.first && a.last ? a.last - a.first : 0;

  L('');
  L('=' .repeat(74) + '=');
  L('  PRE-IMPLEMENTATION PROTOCOL - RUN REPORT' + ' '.repeat(30) + '=');
  L('=' .repeat(74) + '=');
  L(` session   ${a.session.id}`);
  if (FROM) L(` cycle from ${FROM.toISOString().replace('T', ' ').slice(0, 19)} -> TO ${TO ? TO.toISOString().replace('T', ' ').slice(0, 19) : '-'}`);
  L(` start     ${a.first ? a.first.toISOString().replace('T', ' ').slice(0, 19) : '-'}`);
  L(` end       ${a.last ? a.last.toISOString().replace('T', ' ').slice(0, 19) : '-'}`);
  L(` wall time ${dur(wall)}`);
  L(` COST      ${usd(a.mainCost)} (main agent) + ${usd(agentCost)} (subagents = ${usd(total)} of the cost)`);
  L(` TOTAL TOKENS ${n(a.mainOut + a.agentSpawns.reduce((s, x) => s + (x.metrics?.out || 0), 0))} out`);

  // -- steps ----------------------------------------------------------------
  L('');
  L('--- STEPS ' + '-'.repeat(64));
  const seenArt = new Set(a.artifacts.map((art) => art.name));
  for (const [artName, label] of STEPS) {
    if (!seenArt.has(artName)) {
      L(`  - [ ] ${pad(label, 34)} ${pad(artName, 26)} (not reached)`);
      continue;
    }
    const firstArt = a.artifacts.find((art) => art.name === artName);
    const dt = firstArt?.ts && a.first ? dur(firstArt.ts - a.first) : '-';
    L(`  - [x] ${pad(label, 34)} ${pad(artName, 26)} (${dt})`);
  }

  // -- agents ---------------------------------------------------------------
  L('');
  L('=' .repeat(74));
  if (!a.agentSpawns.length) {
    L('  No agents spawned.');
  } else {
    const gpy :any = {};
    for (const z of a.agentSpawns) {
      const g = (gpy[z.type] ||= { n: 0, cost: 0, turns: 0, out: 0, tin: 0, err: 0, ms: 0, tools: 0 });
      g.n++;
      if (z.metrics) {
        g.cost += z.metrics.cost; g.turns += z.metrics.turns;
        g.out += z.metrics.out; g.tin += z.metrics.tin;
        if (z.metrics.first && z.metrics.last) g.ms += z.metrics.last - z.metrics.first;
        g.tools += Object.values(z.metrics.tools || {}).reduce((x, y) => x + y, 0);
      }
    }
    L(` ${pad('agent', 16)}${rp('n', 4)}${rp('cost', 8)}${rp('turns', 6)}${rp('in tok', 8)}${rp('out tok', 9)}${rp('tools', 6)}${rp('avg time', 10)}${rp('cost/t', 8)}${rp('cost%', 7)}`);
    L('-'.repeat(74));
    for (const [t, g] of Object.entries(gpy).sort((a :any, b :any) => b[1].cost - a[1].cost)) {
      L(` ${pad(t, 16)}${rp(g.n, 4)}${rp(usd(g.cost), 8)}${rp(g.turns, 6)}${rp(n(g.tin), 8)}${rp(n(g.out), 9)}${rp(g.tools, 6)}${rp(dur(g.ms / g.n), 10)}${rp(usd(g.cost / (g.n || 1)), 8)}${rp(((100 * g.cost) / (total || 1)).toFixed(0) + '%', 7)}`);
    }
    L('');
    L(` TOTAL SPAWNED: ${n(a.agentSpawns.length)}`);
    L(` SUBAGENTS: ${usd(agentCost)} (${((100 * agentCost) / (total || 1)).toFixed(0)}% of the cost)`);
    if (a.orphanAgents.length) {
      L(` ⚠️  ${n(a.orphanAgents.length)} agent(s) without a transcript found - their cost is not included`);
    }
  }

  // -- what each agent read -------------------------------------------------
  L('');
  L('--- READS ' + '-'.repeat(63));
  const lineCache = {};

  const linesOf = (p) :any | null => {
    if (lineCache[p]) return lineCache[p];
    let v :any = null;
    for (const cand of [p, join(PROJECT_ROOT, p)]) {
      try { if (existsSync(cand) && statSync(cand).isFile()) { v = readFileSync(cand, 'utf8').split('\n'); break; } } catch {}
    }
    return (lineCache[p] = v);
  };

  let partials = 0, anyReads = false;
  for (const s of a.agentSpawns) {
    const rs :any = s.metrics?.reads || [];
    if (!rs.length) continue;
    anyReads = true;
    L(`  ${s.type}(${s.description ? '-' + s.description.slice(0, 40) : ''}):`);

    // group by file and merge ranges - full file + chunk != partial
    const byFile :any = {};
    for (const r of rs) {
      const f = (byFile[r.file] ||= byFile[r.file] || { full: false, ranges: [], n: 0 });
      f.n++;
      if (r.offset && r.limit) { f.full = true; continue; }
      const from = r.offset || 1;
      f.ranges.push([from, r.limit ? from + r.limit - 1 : Infinity]);
    }

    for (const [file, f] of Object.entries(byFile)) {
      const short = basename(file);
      const total = linesOf(file);
      if (f.full) {
        L(`     ${pad(short, 34)} full file${total ? ` (${total} lines)` : ''}${f.n > 1 ? ` (${f.n - 1} chunks)` : ''}`);
        continue;
      }
      // union of the covered lines
      const sorted = f.ranges.sort((x, y) => x[0] - y[0]);
      const merged = [];
      for (const r of sorted) {
        const lastR = merged[merged.length - 1];
        if (lastR && r[0] <= lastR[1] + 1) lastR[1] = Math.max(lastR[1], r[1]);
        else merged.push([r[0], r[1]]);
      }
      const covered = merged.reduce((s, [x, y]) => s + (Math.min(y, total || y) - x + 1), 0);
      const openEnded = merged.some(([, y]) => y === Infinity);
      const pct = number ? total && !openEnded ? Math.round(100 * covered / total) : null;
      const sans = total && !openEnded && covered < total ? 1 : 0;
      if (sans) partials++;
      const span = merged.map(([x, y]) => `${x}-${y === Infinity ? 'end' : y}`).join(', ');
      L(`     ${pad(short, 34)} lines ${pad(span, 16)}${total ? `${total} of ${total}` : ''}${pct != null ? ` (${pct}%)` : ''} ⚠️ PARTIAL = '${s.type}'`);
    }
  }
  if (!anyReads) {
    L('  No Read calls in subagents for this window.');
  } else if (partials) {
    L('');
    L(` ⚠️  ${partials} PARTIAL READS - an agent made a decision without seeing the whole file.`);
    L('    Typical failure: the agent reads only a chunk of the file (e.g. a few lines around');
    L('    the match), misses fields above it and describes the schema wrongly.');
  } else {
    L('');
    L(' ✅ No partial reads - every agent saw the whole files it relied on.');
  }

  // -- hooks ----------------------------------------------------------------
  L('');
  L('--- HOOKS ' + '-'.repeat(63));
  const br :[string,unknown][] = Object.entries(a.hookRuns).sort((x :any, y :any) => y[1].n - x[1].n);
  if (!br.length) {
    L('  No hook fired in this session.');
  } else {
    L(` ${pad('hook', 46)}${rp('runs', 6)}${rp('total ms', 10)}${rp('avg ms', 8)}`);
    for (const [k, v] of br) L(` ${pad(k, 46)}${rp(v.n, 6)}${rp(v.ms, 10)}${rp((v.ms / v.n).toFixed(0), 8)}`);
  }

  if (a.blocks.length) {
    L('');
    L(` 🛑  ${a.blocks.length} BLOCKS - the framework stopped these before they reached the code.`);
    for (const b of a.blocks) L(`   ${b.ts ? b.ts.toISOString().slice(11, 19) : '-'} ${b.reason}`);
  }

  const he :[string,unknown][] = Object.entries(a.hookErrors);
  if (he.length) {
    L('');
    L(' ⚠️  HOOK ERRORS:');
    for (const [c, n] of he) L(`   ${c} (${n})`);
  }

  // -- decision quality -----------------------------------------------------
  L('');
  L('=' .repeat(74));
  if (!dq) {
    L('  solutions.md / solutions-research.md - Step 2.5 did not run.');
  } else {
    const c = dq.confidences;
    const avg = c.length ? c.reduce((x, y) => x + y, 0) / c.length : null;
    L(`  solutions total           ${dq.solutions}`);
    L(`  |- self-select (cheap)    ${dq.selfSelectYes} (${((100 * dq.selfSelectYes) / dq.solutions).toFixed(0)}% of solutions)`);
    L(`  |- researcher+evaluator   ${dq.selfSelectNo} (${((100 * dq.selfSelectNo) / dq.solutions).toFixed(0)}% of solutions)`);
    L('');
    L(`  AUTO-SELECTED             ${dq.autoSelected}`);
    L(`  SELF-SELECTED             ${dq.selfSelectedVerdict}`);
    L(`  UNRESOLVED + question     ${dq.unresolved} (the system said "I do not know")`);
    L(`  REFINEMENT requested      ${dq.refinementReq} (v2 evaluations: ${dq.evaluationV2})`);
    L(`  PROTOTYPE triggered       ${dq.prototypeReq} (prototype evaluations: ${dq.prototypeEval})`);
    L(`  Constraint check: no      ${dq.constraintNo}`);
    L(`  AQC CONCERNS              ${dq.aqcConcerns}`);
    if (avg != null) {
      L('');
      L(`  confidence                avg ${avg.toFixed(1)}% range ${Math.min(...c)}-${Math.max(...c)}% (n=${c.length})`);
      if (clustered) L(' ⚠️  DRIFT: all values within 5 points - the model is probably reproducing the threshold, not measuring');
    }
    if (dq.ddtCovered || dq.ddtMissing) {
      L('');
      L(`  display-data-trace        COVERED ${dq.ddtCovered}  MISSING ${dq.ddtMissing}`);
    }
    if (dq.ditConstraints) L(`  decision-inventory        ${dq.ditConstraints} references to C1-C9`);
  }

  L('');
  L('  Costs are estimates from public pricing (cache write 1.25x input, cache read 0.1x input).');
  L('');
}

// -- main -----------------------------------------------------------------
const sessions :any[] = listSessions();
if (!sessions.length) {
  console.error(`No transcripts in ${TRANSCRIPTS}`);
  process.exit(1);
}

if (has('--list')) {
  console.log(`\nSessions for ${basename(PROJECT_ROOT)} (${sessions.length}):\n`);
  for (const s of sessions) console.log(`  ${s.mtime.toISOString().slice(0, 16).replace('T', ' ')}  ${s.id}`);
  console.log('');
  process.exit(0);
}

const target :T | any = val('--session')
  ? sessions.find((s :T) => s.id.startsWith(val('--session')))
  : sessions[0];
if (!target) { console.error('Session not found. Try --list'); process.exit(1); }

const a = analyze(target);
const dq = decisionQuality();

if (has('--json')) {
  console.log(JSON.stringify({
    session: target.id, first: a.first, last: a.last,
    mainCost: a.mainCost.toFixed(4),
    agentCost: a.agentSpawns.reduce((s, x) => s + (x.metrics?.cost || 0), 0).toFixed(4),
    agents: a.agentSpawns.map((s) => ({
      type: s.type, description: s.description,
      turns: s.metrics?.turns ?? null, cost: s.metrics?.cost?.toFixed(4) ?? null,
    })),
    hooks: a.hookRuns, hookErrors: a.hookErrors, tools: a.tools, decisionQuality: dq,
  }, null, 2));
  process.exit(0);
} else {
  render(a, dq);
  const text :string = lines.join('\n');
  console.log(text);
  if (has('--save')) {
    const dir = join(CLAUDE_DIR, 'metrics', 'runs');
    mkdirSync(dir, { recursive: true });
    const stamp = new Date().toISOString().slice(0, 19).replace(/[:]/g, '-');
    const out = join(dir, `${stamp}-cycle.md`);
    writeFileSync(out, text + '\n', 'utf8');
    console.log(`Saved: ${out}`);
  }
}
