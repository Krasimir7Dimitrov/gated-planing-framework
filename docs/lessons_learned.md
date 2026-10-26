# Lessons Learned

## 2026-01-15 - Read the whole entity before designing a log schema
**Project:** primary
**Problem:** The schema for a new audit log was designed after reading only a few lines around a search match in the reference entity. Fields further up the file (old/new value) were missed, and the first schema draft could not answer "what changed".
**Solution:** For any schema decision, read every field of the reference entity file, not just the matched lines. Document each reference field as INCLUDE or EXCLUDE before choosing options.
**Tags:** schema, audit log, reference project, partial read

## 2026-01-08 - Human-readable text belongs to the frontend
**Project:** both
**Problem:** A meeting requirement "show a description like 'discount-10 was added'" was classified as backend, and a pre-built sentence column was proposed. That breaks translation and violates the one-value-per-column rule.
**Solution:** Store only raw primitives (operation type, IDs, old value, new value). The frontend assembles the sentence.
**Tags:** display, frontend, backend, C9, requirements by layer

## 2025-12-20 - Empty integration host means no-op, not an error
**Project:** secondary
**Problem:** A new courier notification failed in local environments because the courier host parameter was empty, and an extra enable/disable flag was suggested.
**Solution:** Treat an empty host/URL parameter as "do not send". Do not add separate enable/disable flags (C2).
**Tags:** configuration, parameters, integration, C2