import { readFileSync, writeFileSync, existsSync } from 'fs';
import { LESSONS_PATH } from './config.js';

function ensureFile() {
    if (!existsSync(LESSONS_PATH)) {
        writeFileSync(LESSONS_PATH, '# Lessons Learned\n\n', 'utf8');
    }
}

export function getLessons(query, maxResults = 5) {
    ensureFile();
    const text = readFileSync(LESSONS_PATH, 'utf8');
    const tokens = query.toLowerCase().replace(/[^\w\s]/g, ' ').split(/\s+/).filter(Boolean);

    // Split into Lesson blocks by ## header
    const blocks = text.split(/(?=^## )/m).filter((b) => b.startsWith('## '));

    const scored = blocks
        .map((block) => {
            const searchText = block.toLowerCase();
            let score = 0;
            for (const token of tokens) {
                if (searchText.includes(token)) score += 1;
            }
            return { block: block.trim(), score };
        })
        .filter((b) => b.score > 0)
        .sort((a, b) => b.score - a.score)
        .slice(0, maxResults);

    return scored.map((b) => b.block);
}

export function writeLesson(title, problem, solution, project, tags = []) {
    ensureFile();
    const date = new Date().toISOString().slice(0, 10);
    const tagline = tags.length ? tags.join(', ') : 'general';

    const entry = [
        `## ${date} - ${title}`,
        `**Project:** ${project}`,
        `**Problem:** ${problem}`,
        `**Solution:** ${solution}`,
        `**Tags:** ${tagline}`,
        ''
    ].join('\n');

    const existing = readFileSync(LESSONS_PATH, 'utf8');
    // Insert after the H1 header line
    const insertAt = existing.indexOf('\n\n') + 2;
    const updated = existing.slice(0, insertAt) + entry + existing.slice(insertAt);
    writeFileSync(LESSONS_PATH, updated, 'utf8');

    return { written: true, date, title };
}
