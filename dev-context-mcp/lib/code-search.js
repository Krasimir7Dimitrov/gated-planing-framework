import { spawnSync } from 'child_process';
import { RG_EXCLUDE_GLOBS, RG_PATH, targetProjects } from './config.js';

export function searchCode(pattern, project, fileGlob = null, contextLines = 3, maxResults = 20) {
    const targets = targetProjects(project);

    const results = [];

    for (const proj of targets) {
        const srcPaths = proj.src_dirs.map((d) => `${proj.root}/${d}`);

        const args = [
            '--json',
            `--max-count=${maxResults}`,
            `--context=${contextLines}`,
            ...RG_EXCLUDE_GLOBS.map((g) => ['--glob', g]).flat(),
        ];

        if (fileGlob) args.push('--glob', fileGlob);
        args.push(pattern, ...srcPaths);

        const proc = spawnSync(RG_PATH, args, { encoding: 'utf8', timeout: 15000 });

        if (!proc.stdout) continue;

        const lines = proc.stdout.split('\n').filter(Boolean);
        const contextBuffer = [];
        const pendingAfter = new Map(); // result index -> remaining after-lines

        for (const line of lines) {
            let obj;
            try { obj = JSON.parse(line); } catch { continue; }

            if (obj.type === 'context') {
                const text = obj.data.lines.text.trimEnd();
                // attach to pending matches as context_after
                for (const [idx, remaining] of pendingAfter.entries()) {
                    results[idx].context_after.push(text);
                    if (remaining <= 1) pendingAfter.delete(idx);
                    else pendingAfter.set(idx, remaining - 1);
                }
                contextBuffer.push(text);
                if (contextBuffer.length > contextLines) contextBuffer.shift();
                continue;
            }

            if (obj.type === 'begin') { contextBuffer.length = 0; continue; }
            if (obj.type !== 'match') continue;

            // flush pending after-context on new match (they're done)
            pendingAfter.clear();

            const data = obj.data;
            const idx = results.length;
            results.push({
                project: proj.name,
                file: data.path.text.replace(/\\/g, '/').replace(proj.root + '/', ''),
                line: data.line_number,
                match: data.lines.text.trimEnd(),
                context_before: [...contextBuffer],
                context_after: [],
            });
            if (contextLines > 0) pendingAfter.set(idx, contextLines);
            contextBuffer.length = 0;
        }
    }

    return results.slice(0, maxResults);
}
