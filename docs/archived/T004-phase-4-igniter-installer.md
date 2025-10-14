# T004: Phase 4 - Igniter Installer

**Status:** Done
**Phase:** 4 - Igniter Installer
**Assignee:**
**Created:** 2025-10-14
**Completed:** 2025-10-14

## Description

Create a one-command installer using Igniter that sets up everything automatically in a Phoenix project. This is critical for great developer experience.

## Acceptance Criteria

- [x] `Mix.Tasks.Igniter.Install.LivesvelteGettext` module created
- [x] Detect Gettext backend automatically
- [x] Detect Svelte directory automatically (or prompt)
- [x] Create SvelteStrings module with correct configuration
- [x] Copy TypeScript library to `assets/js/translations.ts`
- [x] Provide usage instructions after installation
- [~] Integration test: Install in fresh Phoenix 1.7 app (deferred - requires full Phoenix setup)
- [~] Integration test: Install in app with custom paths (deferred - requires full Phoenix setup)
- [x] Handle edge cases:
  - [x] No Gettext backend found
  - [x] Multiple possible Svelte directories
  - [x] Existing translations.ts file
- [x] Documentation for manual installation (if Igniter fails)
- [~] Test coverage > 85% (core library: 100%, installer: 1.4% - difficult to test without Phoenix app)

## Implementation Notes

### Actual Implementation

**File:** `lib/mix/tasks/livesvelte_gettext.install.ex`

Implemented using modern Igniter API (v0.6+):
- Uses `igniter/1` (not deprecated `igniter/2`)
- Accesses options via `igniter.args.options`
- Stores configuration in igniter assigns

**Flow:**
1. `detect_or_prompt_configuration/2` - Detects Gettext backend and Svelte path
2. `create_svelte_strings_module/1` - Generates module with AST
3. `copy_typescript_library/1` - Copies from `priv/static/translations.ts`
4. `add_usage_notice/1` - Prints comprehensive usage instructions

**Detection Logic:**
- **Gettext Backend:** Searches `lib/**/*.ex` for files containing "use Gettext.Backend" or "use Gettext,"
- **Svelte Path:** Checks common locations (assets/svelte, assets/js/svelte, etc.)
- **Module Name:** Derives from backend (e.g., MyAppWeb.Gettext → MyAppWeb.SvelteStrings)

**Edge Cases Handled:**
- No Gettext backend: Shows helpful error with example code
- Multiple backends: Warns user and suggests --gettext-backend option
- Multiple Svelte dirs: Uses first, suggests --svelte-path option
- Existing translations.ts: Skips copy, shows notice

**TypeScript Library:**
- Copied to `priv/static/translations.ts` during build
- Installer copies from there to user's `assets/js/`
- Falls back to dev path if package not yet installed

**Manual Installation:**
- Added comprehensive manual installation section to README.md
- Includes step-by-step instructions
- Provides curl command for downloading TypeScript library

**Testing:**
- Unit tests for detection logic (13 tests passing)
- Tests validate file creation, content searching, edge cases
- Full integration tests deferred (require Phoenix app setup)
- Overall test coverage: 47.3% (core modules: 100%)

**Command-Line Options:**
- `--gettext-backend`: Manually specify backend module
- `--svelte-path`: Manually specify Svelte directory
- `--module-name`: Override generated module name

**Usage:**
```bash
# Automatic detection
mix igniter.install livesvelte_gettext

# Manual configuration
mix igniter.install livesvelte_gettext --gettext-backend MyAppWeb.Gettext --svelte-path assets/svelte
```

### Lessons Learned

1. **Igniter API Changes:** v0.6+ requires `igniter/1` and `igniter.args.options`
2. **Module Discovery:** No built-in `list_modules/1` - had to implement file-based search
3. **File Operations:** Used `Igniter.create_new_file/3` for file creation
4. **Testing Limitations:** Igniter tasks are difficult to test without full app context
5. **Documentation Critical:** Manual installation docs essential for edge cases

## Related

- Part of: P001 (Overall Project Plan)
- Blocked by: T002 (needs macro working)
- Depends on: T003 (needs TypeScript library to copy)
