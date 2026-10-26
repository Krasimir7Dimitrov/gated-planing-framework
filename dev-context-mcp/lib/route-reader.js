import { spawnSync } from 'child_process';
import { existsSync, readdirSync, readFileSync } from 'fs';
import { targetProjects } from './config.js';

function routesFromConsole(proj) {
    const proc = spawnSync(
        'php',
        ['bin/console', 'debug:router', '--format=json', '--env=dev'],
        { cwd: proj.root, encoding: 'utf8', timeout: 10000 }
    );

    if (proc.status !== 0 || !proc.stdout) return null;

    try {
        const raw = JSON.parse(proc.stdout);
        return Object.entries(raw).map(([name, r]) => ({
            project: proj.name,
            name,
            path: r.path,
            methods: r.methods?.length ? r.methods : ['ANY'],
            controller: r.defaults?.controller ?? '',
        }));
    } catch {
        return null;
    }
}

function routesFromAttributes(proj) {
    const controllerDirs = [
        `${proj.root}/src/Controller`,
        `${proj.root}/src/Api`,
    ].filter(existsSync);

    const routes = [];

    function scanDir(dir) {
        for (const entry of readdirSync(dir, { withFileTypes: true })) {
            const full = `${dir}/${entry.name}`;
            if (entry.isDirectory()) { scanDir(full); continue; }
            if (!entry.name.endsWith('.php')) continue;

            const src = readFileSync(full, 'utf8');

            // PHP 8 attribute style: #[Route('/path', name: 'name', methods: ['GET'])]
            const attrRe = /#\[Route\(\s*(['"])([^'"]+)\1\s*(?:,\s*name\s*:\s*(['"])([^'"]+)\3)?(?:,\s*methods\s*:\s*\[([^\]]+)\])?\s*\)\s*\]/g;
            let m;
            while ((m = attrRe.exec(src)) !== null) {
                const methods = m[5]
                    ? m[5].split(',').map((s) => s.trim().replace(/^['"]|['"]/g, ''))
                    : ['ANY'];
                routes.push({
                    project: proj.name,
                    name: m[4] ?? '',
                    path: m[2],
                    methods,
                    controller: full.replace(/\\/g, '/').replace(proj.root + '/', ''),
                });
            }

            // Annotation style: @Route("/path", name="name", methods={"GET"})
            const annRe = /@Route\(\s*(['"])([^'"]+)\1\s*(?:,\s*name\s*=\s*(['"])([^'"]+)\3)?(?:,\s*methods\s*=\s*\{([^\}]+)\})?\s*\)/g;
            while ((m = annRe.exec(src)) !== null) {
                const methods = m[5]
                    ? m[5].split(',').map((s) => s.trim().replace(/^['"]|['"]/g, ''))
                    : ['ANY'];
                routes.push({
                    project: proj.name,
                    name: m[4] ?? '',
                    path: m[2],
                    methods,
                    controller: full.replace(/\\/g, '/').replace(proj.root + '/', ''),
                });
            }
        }
    }

    controllerDirs.forEach(scanDir);
    return routes;
}

export function getRoutes(project, filter = null) {
    const targets = targetProjects(project);

    let results = [];
    for (const proj of targets) {
        const fromConsole = routesFromConsole(proj);
        results.push(...(fromConsole ?? routesFromAttributes(proj)));
    }

    if (filter) {
        const f = filter.toLowerCase();
        results = results.filter(
            (r) => r.name.toLowerCase().includes(f) || r.path.toLowerCase().includes(f)
        );
    }

    return results;
}
