import { readFileSync, existsSync } from 'fs';
import { BUNDLE_DIRS, PROJECTS, targetProjects } from './config.js';

function findEntityFile(entityName, proj) {
    const candidates = [
        `${proj.root}/src/Entity/${entityName}.php`,
        ...BUNDLE_DIRS.map((b) => `${proj.root}/${b}/src/Entity/${entityName}.php`),
    ];
    return candidates.find(existsSync) ?? null;
}

function parseEntity(filePath, projName, entityName) {
    const src = readFileSync(filePath, 'utf8');
    const fields = [];
    const constants = {};

    // ORM Column (attribute or annotation style)
    const columnRe = /#\[ORM\.Column|@ORM\.Column/g;
    let m;
    while ((m = columnRe.exec(src)) !== null) {
        const context = src.slice(m.index, m.index + 350);
        const property = context.match(/(?:private|protected|public)\s+\??([a-zA-Z0-9_]+)\s+\$([a-zA-Z0-9_]+)/);
        if (!property) continue;
        const type = context.match(/(?:type\s*=\s*["']([^"']+)["']|type:\s*["']([^"']+)["'])/);
        fields.push({
            name: property[2],
            type: type ? (type[1] || type[2]) : property[1],
            nullable: /nullable\s*(?:=|:)\s*true/.test(context),
        });
    }

    // Relations
    const relRe = /@ORM\.(ManyToOne|OneToMany|ManyToMany|OneToOne)|#\[ORM\.(ManyToOne|OneToMany|ManyToMany|OneToOne)/g;
    while ((m = relRe.exec(src)) !== null) {
        const context = src.slice(m.index, m.index + 350);
        const property = context.match(/(?:private|protected|public)\s+\??([a-zA-Z0-9_]+)\s+\$([a-zA-Z0-9_]+)/);
        if (property) fields.push({ name: property[2], type: m[1] || m[2], relation: true });
    }

    // Constants
    const constRe = /const\s+(\w+)\s*=\s*(.+?);/g;
    while ((m = constRe.exec(src)) !== null) {
        const val = m[2].trim().replace(/^["']|["']/g, '');
        constants[m[1]] = isNaN(val) ? val : Number(val);
    }

    return {
        project: projName,
        entity: entityName,
        file: filePath.replace(/\\/g, '/').replace(PROJECTS[projName]?.root + '/', ''),
        fields,
        constants,
    };
}

export function getEntitySchema(entityName, project) {
    const targets = targetProjects(project);

    const results = [];
    for (const proj of targets) {
        const filePath = findEntityFile(entityName, proj);
        if (filePath) results.push(parseEntity(filePath, proj.name, entityName));
    }
    return results;
}
