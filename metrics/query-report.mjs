#!/usr/bin/env node
// Report on the retrieval queries agents make through the MCP server.
//
// Measures what CLAUDE.md compensates for with a rule:
// "not present is only valid after at least 3 different search terms"
// If search worked on the first try, that rule would not need to exist.
//
// node .claude/metrics/query-report.mjs
// node .claude/metrics/query-report.mjs --since 2026-09-23
// node .claude/metrics/query-report.mjs --json

import { readFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';

// telemetryPath from framework.config.json, if set - the same file the MCP server writes to.
const CONFIG = join(process.cwd(), 'framework.config.json');
const telemetryPath :any | null = existsSync(CONFIG) ? JSON.parse(readFileSync(CONFIG, 'utf8')).telemetryPath : null;
const LOG = telemetryPath
  ? resolve(process.cwd(), telemetryPath)
  : join(process.cwd(), '.claude', 'metrics', 'mcp-queries.jsonl');
const CHAIN_WINDOW_MS :number = 180_000; // attempts at the same tool within 3 min = one chain

const argv = process.argv.slice(2);
const has = (f) => argv.includes(f);
const val = (f) :any | null => { const i = argv.indexOf(f); return i >= 0 ? argv[i + 1] : null; };
const SINCE :Date | null = val('--since') ? new Date(val('--since')) : null;

if (!existsSync(LOG)) {
  console.error(`No ${LOG}
Telemetry is filled when agents call the MCP tools.`);
  process.exit(1);
}

const rows :any[] = [];
for (const line :any of readFileSync(LOG, 'utf8').split('
')) {
  if (!line.trim()) continue;
  try {
    const r = JSON.parse(line);
    r.ts = new Date(r.ts);
    if (SINCE && r.ts < SINCE) continue;
    rows.push(r);
  } catch {}
}

if (!rows.length) { console.error('The log is empty for this period.'); process.exit(1); }
rows.sort((a, b) => a.ts - b.ts);

// -- per tool -------------------------------------------------------------
const byTool :any = {};
for (const r of rows) {
  const t = (byTool[r.tool] ||= { n: 0, empty: 0, ms: 0, errors: 0 });
  t.n++; t.ms += r.ms || 0;
  if (r.empty) t.empty++;
  if (r.error) t.errors++;
}

// -- attempt chains -------------------------------------------------------
// Chain = consecutive calls to the SAME tool in the same session, within the
// window. The interesting ones have length > 1 - the agent searched again.
const chains :any[] = [];
const bySessionTool :any = {};
for (const r of rows) {
  const key :string = `${r.session}|${r.tool}`;
  const prev = bySessionTool[key];
  if (prev && r.ts - prev.last.ts <= CHAIN_WINDOW_MS) {
    prev.items.push(r);
    prev.last = r;
  } else {
    const chain = { tool: r.tool, session: r.session, items: [r], last: r };
    bySessionTool[key] = chain;
    chains.push(chain);
  }
}

const multi :any[] = chains.filter((c) :boolean => c.items.length > 1);
const wasted = multi.reduce((s, c) => s + c.items.filter((i :any) => i.empty).length, 0);
const succeededEventually :number = multi.filter((c) => c.items.some((i :any) => !i.empty)).length;

// -- failed terms ---------------------------------------------------------
const failedTerms :any = {};
for (const r of rows) {
  if (!r.empty) continue;
  const term = Object.values(r.query || {}).filter((v :boolean => typeof v === 'string')[0];
  if (term) failedTerms[`${r.tool}:${term}`] = (failedTerms[`${r.tool}:${term}`] || 0) + 1;
}

if (has('--json')) {
  console.log(JSON.stringify({
    total: rows.length,
    from: rows[0].ts, to: rows[rows.length - 1].ts,
    sessions: new Set(rows.map((r) => r.session)).size,
    byTool, chains: chains.length, multiAttemptChains: multi.length,
    wastedCalls: wasted, failedTerms,
  }, null, 2));
  process.exit(0);
}

const n = (x) :string => String(x).padStart(9);
const pad = (s, w) :string => String(s).padEnd(w);
const pct = (a, b) :string => (b ? (100 * a / b).toFixed(0) + '%' : '-');

console.log();
console.log('='.repeat(74));
console.log(' RETRIEVAL TELEMETRY - what agents search for and whether they find it');
console.log('='.repeat(74));
console.log(' period    ', `${rows[0].ts.slice(0, 19)} -> ${rows[rows.length - 1].ts.slice(0, 19)}`);
console.log(' sessions  ', `${new Set(rows.map((r) => r.session)).size}`);
console.log(' queries   ', `${rows.length}`);

const totalEmpty :number = rows.filter((r) => r.empty).length;
console.log(' EMPTY     ', `${totalEmpty} (${pct(totalEmpty, rows.length)}) - the agent searched and found nothing`);

console.log();

const h = (x) :string => String(x).padStart(9);
console.log(` ${pad('tool', 26)}${h('queries')}${h('empty')}${h('%')}${h('avg ms')}`);
console.log('-'.repeat(68));
for (const [t, v] of Object.entries(byTool).sort((a :[string,unknown], b :[string,unknown]) => b[1].n - a[1].n)) {
  console.log(` ${pad(t, 26)}${n(v.n)}${n(v.empty)}${n(pct(v.empty, v.n))}${n((v.ms / v.n).toFixed(0))}`);
}

console.log();
console.log('--- ATTEMPT CHAINS ' + '-'.repeat(55));
console.log(' chains total       ', `${chains.length}`);
console.log(' with more than one attempt ', `${multi.length} (${pct(multi.length, chains.length)})`);
console.log(' of these, found in the end ', `${succeededEventually}`);
console.log(' wasted calls       ', `${wasted}`);
if (multi.length) {
  const avg :number = multi.reduce((s, c) => s + c.items.length, 0) / multi.length;
  console.log(' avg attempts per chain ', `${avg.toFixed(2)}`);
  console.log();
  console.log(' longest chains:');
  for (const c of multi.sort((a, b) => b.items.length - a.items.length).slice(0, 8)) {
    console.log(`   ${c.tool} (${c.items.length} attempts)`);
    for (const i :any of c.items) {
      const term = Object.values(i.query || {}).filter((v :boolean => typeof v === 'string')[0] || '';
      console.log(`     ${i.empty ? 'X' : 'v'} "${String(term).slice(0, 52).padEnd(54)} ${i.results} res."`);
    }
  }
}

const ft :[string,unknown][] = Object.entries(failedTerms).sort((a :[string,unknown], b :[string,unknown]) => b[1] - a[1]).slice(0, 12);
if (ft.length) {
  console.log();
  console.log('-- TERMS THAT FIND NOTHING ' + '-'.repeat(46));
  for (const [term, n] of ft) console.log(` ${n(n)}  ${term.slice(0, 62)}`);
}
console.log();
