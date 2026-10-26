import { appendFileSync, mkdirSync } from 'fs';
import { dirname } from 'path';
import { TELEMETRY_PATH } from './config.js';

// Each MCP server process = one Claude Code session. This id ties together
// the queries of one session, so retry chains can be seen.
const SESSION = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;

let ready = false;

function ensureDir() {
    if (ready) return;
    mkdirSync(dirname(TELEMETRY_PATH), { recursive: true });
    ready = true;
}

/** Counts results regardless of the shape each tool returns. */
function countResults(value) {
    if (value == null) return 0;
    if (Array.isArray(value)) return value.length;
    if (typeof value === 'string') return value.trim() ? 1 : 0;
    if (typeof value === 'object') {
        if (value.error) return 0;
        for (const key of ['results', 'matches', 'fields', 'routes', 'chunks', 'lessons']) {
            if (Array.isArray(value[key])) return value[key].length;
        }
        return Object.keys(value).length;
    }
    return 1;
}

/**
 * Runs fn, writes one telemetry line and returns the result unchanged.
 * instrument('search_code', { pattern, project }, () => searchCode(...))
 * A logging failure never breaks the tool.
 */
export function instrument(tool, query, fn) {
    const started = Date.now();
    let value;
    let error = null;
    try {
        value = fn();
        return value;
    } catch (err) {
        error = err?.message ? String(err.message).slice(0, 200) : 'error';
        throw err;
    } finally {
        try {
            ensureDir();
            const results = error ? 0 : countResults(value);
            const clean = {};
            for (const [k, v] of Object.entries(query || {})) {
                if (v !== undefined && v !== null) clean[k] = v;
            }
            appendFileSync(TELEMETRY_PATH, JSON.stringify({
                ts: new Date().toISOString(),
                session: SESSION,
                tool,
                query: clean,
                results,
                empty: results === 0,
                ms: Date.now() - started,
                error,
            }) + '\n', 'utf8');
        } catch {
            /* telemetry never breaks the tool */
        }
    }
}
