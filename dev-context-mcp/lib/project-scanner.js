import { readdirSync, existsSync } from 'fs';
import { BUNDLE_DIRS, PROJECTS } from './config.js';

function listNames(dir) {
    if (!existsSync(dir)) return [];
    return readdirSync(dir, { withFileTypes: true })
        .filter((e) => e.isFile() && e.name.endsWith('.php'))
        .map((e) => e.name.replace('.php', ''));
}

function fromBundles(root, sub) {
    return BUNDLE_DIRS.flatMap((b) =>
        listNames(`${root}/${b}/src/${sub}`).map((n) => `[bundle] ${n}`)
    );
}

export function getProjectContext(project) {
    const proj = PROJECTS[project];
    if (!proj) return { error: `project "${project}" is not defined in framework.config.json` };
    const root = proj.root;

    const result = {
        project,
        controllers: listNames(`${root}/src/Controller`),
        services: [
            ...listNames(`${root}/src/Service`),
            ...fromBundles(root, 'Service'),
        ],
        entities: [
            ...listNames(`${root}/src/Entity`),
            ...fromBundles(root, 'Entity'),
        ],
        repositories: [
            ...listNames(`${root}/src/Repository`),
            ...fromBundles(root, 'Repository'),
        ],
        messenger_handlers: listNames(`${root}/src/MessageHandler`),
        webhook_handlers: listNames(`${root}/src/WebhookHandler`),
    };

    const bundles = BUNDLE_DIRS
        .filter((b) => existsSync(`${root}/${b}`))
        .flatMap((b) => readdirSync(`${root}/${b}`, { withFileTypes: true })
            .filter((entry) => entry.isDirectory())
            .map((entry) => entry.name));
    if (bundles.length) result.bundles = bundles;

    return result;
}
