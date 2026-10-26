import { existsSync, readFileSync } from 'fs';
import { dirname, isAbsolute, join, resolve } from 'path';
import { fileURLToPath } from 'url';

// The config is looked up in this order:
// 1. FRAMEWORK_CONFIG (env) - absolute or relative path to the file
// 2. framework.config.json in the current folder (Claude Code starts the server from the project)
// 3. framework.config.json in the folder above dev-context-mcp/
// Relative paths in the config are resolved against the folder that contains the file.
const SERVER_DIR = dirname(dirname(fileURLToPath(import.meta.url)));

function findConfig() {
    const candidates = [
        process.env.FRAMEWORK_CONFIG && resolve(process.env.FRAMEWORK_CONFIG),
        join(process.cwd(), 'framework.config.json'),
        join(SERVER_DIR, 'framework.config.json'),
    ].filter(Boolean);
    const found = candidates.find(existsSync);
    if (!found) {
        throw new Error(`framework.config.json not found. Looked in: ${candidates.join(', ')}`);
    }
    return found;
}

const CONFIG_PATH = findConfig();
const CONFIG_DIR = dirname(CONFIG_PATH);
const cfg = JSON.parse(readFileSync(CONFIG_PATH, 'utf8'));

// All paths use / - the rest of the code strips the project root from rg paths
// with replace(root + '/', ''), after turning \ into /.

function toPath(p) {
    return (isAbsolute(p) ? p : resolve(CONFIG_DIR, p)).replace(/\\/g, '/');
}

export const RG_PATH = cfg.rgPath || 'rg';

export const PROJECTS = {};
for (const [name, p] of Object.entries(cfg.projects || {})) {
    PROJECTS[name] = {
        name,
        root: toPath(p.root || '.'),
        src_dirs: p.src_dirs || p.srcDirs || ['src'],
    };
}
if (!PROJECTS.primary) {
    throw new Error(`${CONFIG_PATH}: projects.primary is required`);
}

// Bundle folders, relative to each project root (e.g. "mybundle").
// Each is expected to contain src/Entity, src/Service, src/Repository.
export const BUNDLE_DIRS = cfg.bundleDirs || [];

export const REFERENCE_PROJECTS = (cfg.referenceProjects || []).map((r) => ({
    name: r.name,
    path: toPath(r.path),
}));

export const BUSINESS_LOGIC_PATH = toPath(cfg.businessLogicPath || 'docs/BUSINESS_LOGIC.md');

export const LESSONS_PATH = toPath(cfg.lessonsPath || 'docs/lessons_learned.md');

// Log of every retrieval query the agents make. Lives next to the framework's
// metrics, so run-report can correlate them by time.
export const TELEMETRY_PATH = toPath(cfg.telemetryPath || '.claude/metrics/mcp-queries.jsonl');

/** The projects for 'primary' | 'secondary' | 'both'; a missing project is simply skipped. */
export function targetProjects(project) {
    const names = project === 'both' ? ['primary', 'secondary'] : [project];
    return names.map((n) => PROJECTS[n]).filter(Boolean);
}

export const RG_EXCLUDE_GLOBS = [
    '/vendor/**',
    '/node_modules/**',
    '/var/**',
    '/migrations/**',
    // The public root holds the Ext JS framework and build artifacts (170MB+).
    // If public/ui/app holds real frontend code, add it to srcDirs in
    // framework.config.json - it is deliberately not excluded here.
    '/public/ui/ext/**',
    '/public/ui/build/**',
    '/public/ui/resources/**',
    '/public/ui/packages/**',
];
