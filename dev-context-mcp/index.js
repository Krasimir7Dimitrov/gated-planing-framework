import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';

import { search as searchBusinessLogic } from './lib/business-logic-parser.js';
import { searchCode } from './lib/code-search.js';
import { getRoutes } from './lib/route-reader.js';
import { getEntitySchema } from './lib/entity-parser.js';
import { getProjectContext } from './lib/project-scanner.js';
import { getLessons, writeLesson } from './lib/lessons.js';
import { instrument } from './lib/telemetry.js';

const server = new McpServer({
    name: 'dev-context',
    version: '1.0.0',
});

server.tool(
    'search_business_logic',
    'Search the BUSINESS_LOGIC.md documentation by keyword. Returns relevant sections with header path and context. Call this AFTER get_lessons when working on a new feature.',
    {
        query: z.string().describe('Keywords to search for'),
        max_results: z.number().optional().default(5).describe('Max sections to return'),
    },
    async ({ query, max_results }) => ({
        content: [{ type: 'text', text: JSON.stringify(instrument('search_business_logic', { query }, () => searchBusinessLogic(query, max_results)), null, 2) }],
    })
);

server.tool(
    'search_code',
    'Search source code in primary and/or secondary project using ripgrep. Returns file paths, line numbers, and context.',
    {
        pattern: z.string().describe('Ripgrep regex pattern'),
        project: z.enum(['primary', 'secondary', 'both']).describe('Which project to search'),
        file_glob: z.string().optional().describe('File filter e.g. "*.php", "*.vue"'),
        context_lines: z.number().optional().default(3).describe('Lines of context around match'),
        max_results: z.number().optional().default(20),
    },
    async ({ pattern, project, file_glob, context_lines, max_results }) => ({
        content: [{ type: 'text', text: JSON.stringify(instrument('search_code', { pattern, project, file_glob }, () => searchCode(pattern, project, file_glob, context_lines, max_results)), null, 2) }],
    })
);

server.tool(
    'get_routes',
    'Get Symfony route table from primary and/or secondary project. Uses php bin/console debug:router, then falls back to scanning route attributes and annotations.',
    {
        project: z.enum(['primary', 'secondary', 'both']),
        filter: z.string().optional().describe('Substring filter on route name or path'),
    },
    async ({ project, filter }) => ({
        content: [{ type: 'text', text: JSON.stringify(instrument('get_routes', { project, filter }, () => getRoutes(project, filter)), null, 2) }],
    })
);

server.tool(
    'get_entity_schema',
    'Parse a Doctrine entity PHP file and return its fields, types, relations, and constants. No DB call needed.',
    {
        entity_name: z.string().describe('Entity class name e.g. "Order", "OrderItem"'),
        project: z.enum(['primary', 'secondary', 'both']),
    },
    async ({ entity_name, project }) => ({
        content: [{ type: 'text', text: JSON.stringify(instrument('get_entity_schema', { entity_name, project }, () => getEntitySchema(entity_name, project)), null, 2) }],
    })
);

server.tool(
    'get_project_context',
    'Get a structural overview of a project: controllers, services, entities, repositories, handlers. Call this first when starting work on an unfamiliar area.',
    {
        project: z.enum(['primary', 'secondary']),
    },
    async ({ project }) => ({
        content: [{ type: 'text', text: JSON.stringify(instrument('get_project_context', { project }, () => getProjectContext(project)), null, 2) }],
    })
);

server.tool(
    'get_lessons',
    'Search lessons_learned.md for past mistakes and solutions relevant to the current task. Call this FIRST before any other tool when starting a new feature or fix.',
    {
        query: z.string().describe('Keywords related to the current task'),
        max_results: z.number().optional().default(5),
    },
    async ({ query, max_results }) => ({
        content: [{ type: 'text', text: JSON.stringify(instrument('get_lessons', { query }, () => getLessons(query, max_results)), null, 2) }],
    })
);

server.tool(
    'write_lesson',
    'Append a new lesson to lessons_learned.md after completing a task where a non-obvious problem was encountered.',
    {
        title: z.string().describe('Short title of the lesson'),
        problem: z.string().describe('What went wrong or was non-obvious'),
        solution: z.string().describe('The correct approach'),
        project: z.enum(['primary', 'secondary', 'both']),
        tags: z.array(z.string()).optional().default([]).describe('Keywords for future retrieval'),
    },
    async ({ title, problem, solution, project, tags }) => ({
        content: [{ type: 'text', text: JSON.stringify(instrument('write_lesson', { title, problem, solution, project, tags }, () => writeLesson(title, problem, solution, project, tags)), null, 2) }],
    })
);

await server.connect(new StdioServerTransport());
