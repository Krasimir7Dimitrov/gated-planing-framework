import { readFileSync } from 'fs';
import { BUSINESS_LOGIC_PATH } from './config.js';

let cachedChunks = null;

function parseChunks() {
    const text = readFileSync(BUSINESS_LOGIC_PATH, 'utf8');
    const lines = text.split('\n');
    const chunks = [];
    const stack = [null, null, null, null, null, null]; // index = level 1-6
    let current = null;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const m = line.match(/^(#{1,6})\s+(.*)/);

        if (m) {
            const level = m[1].length;
            const title = m[2].trim();

            if (current) {
                current.content = current.contentLines.join('\n').trim();
                delete current.contentLines;
                chunks.push(current);
            }

            stack[level - 1] = title;
            for (let j = level; j < 6; j++) stack[j] = null;

            const header_path = stack.filter(Boolean).join(' > ');
            current = { level, title, header_path, contentLines, line_start: i + 1 };
        } else if (current) {
            current.contentLines.push(line);
        }
    }

    if (current) {
        current.content = current.contentLines.join('\n').trim();
        delete current.contentLines;
        chunks.push(current);
    }

    return chunks;
}

function getChunks() {
    if (!cachedChunks) cachedChunks = parseChunks();
    return cachedChunks;
}

export function search(query, maxResults = 5) {
    const chunks = getChunks();
    const tokens = query.toLowerCase().replace(/[^\w\s]/g, ' ').split(/\s+/).filter(Boolean);

    const scored = chunks
        .map((chunk) => {
            const searchText = (chunk.header_path + ' ' + chunk.content).toLowerCase();
            const headerText = chunk.header_path.toLowerCase();
            let score = 0;
            for (const token of tokens) {
                if (searchText.includes(token)) score += 1;
                if (headerText.includes(token)) score += 2;
            }
            return { ...chunk, score };
        })
        .filter((c) => c.score > 0)
        .sort((a, b) => b.score - a.score)
        .slice(0, maxResults);

    return scored.map((c) => ({
        header_path: c.header_path,
        level: c.level,
        line_start: c.line_start,
        score: c.score,
        content: c.content.slice(0, 1000),
    }));
}
