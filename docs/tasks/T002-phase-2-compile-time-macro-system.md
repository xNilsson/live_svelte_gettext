# T002: Phase 2 - Compile-Time Macro System

**Status:** Not Started
**Phase:** 2 - Compile-Time Macro System
**Assignee:**
**Created:** 2025-10-14
**Completed:**

## Description

Build the `use LiveSvelteGettext` macro that generates code at compile time. This is the "magic" that makes everything work without generated files.

## Acceptance Criteria

- [ ] `LiveSvelteGettext` main module with `__using__/1` macro
- [ ] `LiveSvelteGettext.Compiler` for AST generation
- [ ] Configuration validation (gettext_backend, svelte_path required)
- [ ] `@external_resource` integration for auto-recompilation
- [ ] Generate `gettext()` calls that mix gettext.extract can discover
- [ ] Generate `ngettext()` calls for plurals
- [ ] Runtime `all_translations()` function generation
- [ ] Debug function `__lsg_metadata__/0` for troubleshooting
- [ ] Tests for generated code correctness
- [ ] Test that @external_resource triggers recompilation
- [ ] Integration test: full compile cycle
- [ ] Test coverage > 90%

## Implementation Notes

Core macro structure:
1. Validate options at compile time
2. Scan Svelte files using Extractor
3. Generate AST with:
   - `use Gettext, backend: ...`
   - `@external_resource` for each Svelte file
   - Generated `gettext()` calls (for extraction)
   - Generated `all_translations()` function (for runtime)

Key challenges:
- Macro hygiene (use `unquote_splicing` correctly)
- Proper escaping in generated code
- Making sure Gettext extractor can discover our calls
- Runtime translation map construction

Testing strategy:
- Create test modules using the macro
- Verify expected functions exist
- Test actual translation at runtime
- Verify recompilation behavior (tricky - may need integration test)

## Related

- Part of: P001 (Overall Project Plan)
- Blocked by: T001 (needs Extractor working)
- Blocks: T004 (Igniter installer needs this working)
