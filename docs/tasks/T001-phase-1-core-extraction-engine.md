# T001: Phase 1 - Core Extraction Engine

**Status:** Not Started
**Phase:** 1 - Core Extraction Engine
**Assignee:**
**Created:** 2025-10-14
**Completed:**

## Description

Build the Svelte string extraction logic that scans `.svelte` files and extracts translation strings from `gettext()` and `ngettext()` calls.

This is the foundation of the entire library - it needs to handle all edge cases correctly.

## Acceptance Criteria

- [ ] `LiveSvelteGettext.Extractor` module created
- [ ] Extract `gettext("string")` calls
- [ ] Extract `gettext("string", %{vars})` with interpolation
- [ ] Extract `ngettext("singular", "plural", count)` calls
- [ ] Handle single and double quotes
- [ ] Handle escaped quotes (e.g., `\"` and `\'`)
- [ ] Track file:line metadata for each extraction
- [ ] Deduplication logic (group by msgid, preserve all references)
- [ ] Comprehensive test suite with fixtures
  - [ ] Unit tests for regex patterns
  - [ ] Integration tests with fixture Svelte files
  - [ ] Edge cases (multiline, comments, nested strings)
- [ ] Test coverage > 90%

## Implementation Notes

Key considerations:
- Use regex to extract strings (see project plan for examples)
- Need to handle both JavaScript/TypeScript template syntax in Svelte
- Unescape strings properly (`\\` → `\`)
- Group duplicates but keep all file:line references
- Return structured data: `%{msgid, type, plural, references}`

Test fixtures should include:
- Simple gettext calls
- Interpolation with variables
- Pluralization
- Edge cases (escaped quotes, multiline, comments)

## Related

- Part of: P001 (Overall Project Plan)
- Blocks: T002 (Compiler needs Extractor output)
