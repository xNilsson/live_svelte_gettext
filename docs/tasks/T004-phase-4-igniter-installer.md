# T004: Phase 4 - Igniter Installer

**Status:** Not Started
**Phase:** 4 - Igniter Installer
**Assignee:**
**Created:** 2025-10-14
**Completed:**

## Description

Create a one-command installer using Igniter that sets up everything automatically in a Phoenix project. This is critical for great developer experience.

## Acceptance Criteria

- [ ] `Mix.Tasks.Igniter.Install.LivesvelteGettext` module created
- [ ] Detect Gettext backend automatically
- [ ] Detect Svelte directory automatically (or prompt)
- [ ] Create SvelteStrings module with correct configuration
- [ ] Copy TypeScript library to `assets/js/translations.ts`
- [ ] Provide usage instructions after installation
- [ ] Integration test: Install in fresh Phoenix 1.7 app
- [ ] Integration test: Install in app with custom paths
- [ ] Handle edge cases:
  - [ ] No Gettext backend found
  - [ ] Multiple possible Svelte directories
  - [ ] Existing translations.ts file
- [ ] Documentation for manual installation (if Igniter fails)
- [ ] Test coverage > 85%

## Implementation Notes

Igniter flow:
1. `detect_configuration/1` - Find Gettext backend and Svelte path
2. `create_svelte_strings_module/1` - Generate module code
3. `copy_typescript_library/1` - Copy from priv/ to assets/
4. `add_usage_instructions/1` - Print helpful next steps

Key challenges:
- Finding Gettext backend (search for `use Gettext` in modules)
- Handling different Svelte directory conventions
- Not overwriting existing files
- Clear error messages if detection fails

Usage instructions should include:
- How to inject translations in LiveView
- How to initialize in Svelte component
- How to extract and merge translations
- Link to full documentation

Testing:
- Unit tests for detection logic
- Integration test: fresh Phoenix app (may need Docker or tmp dir)
- Manual testing in multiple project types

## Related

- Part of: P001 (Overall Project Plan)
- Blocked by: T002 (needs macro working)
- Depends on: T003 (needs TypeScript library to copy)
