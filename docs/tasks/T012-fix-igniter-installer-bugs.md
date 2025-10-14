# T012: Fix Igniter Installer Bugs

> **📝 UPDATE:** After completing this task, the approach was simplified further - the setup wizard was also removed in favor of fully automatic lazy initialization (no JavaScript setup required at all). See CHANGELOG.md v0.1.1 for the final implementation.

**Status:** Completed
**Phase:** 1 - Core Library
**Created:** 2025-10-14
**Completed:** 2025-10-14

## Description

The Igniter installer (v0.1.1) had several critical bugs discovered during real-world testing with the monster_construction project. Rather than fix all the fragile JavaScript regex parsing, we refactored to a cleaner approach with manual JavaScript setup.

## Issues Discovered

### Issue 1: JavaScript Import Placement (FIXED)
**Problem:** The installer adds the import statement after the FIRST import in the file, which could be a comment like `// import "./user_socket.js"`

**Example:**
```javascript
// import "./user_socket.js"  <-- This is a comment!
import { LiveSvelteGettextInit } from "live-svelte-gettext";  // Added here (wrong!)
import "phoenix_html";
import { Socket } from "phoenix";
```

**Root Cause:** `lib/mix/tasks/live_svelte_gettext.install.ex:378-395` - Uses regex `~r/(import\s+.*\n)(\n)/` which matches comments

**Solution:** Find the LAST actual import statement (not comments), then insert after it
- Parse lines and find last line starting with "import " (trimmed)
- Insert new import after that line

**Status:** ✅ FIXED

---

### Issue 2: JavaScript Hook Syntax Error (FIXED)
**Problem:** Creates invalid JavaScript syntax with double commas when adding hook to existing hooks object

**Example:**
```javascript
hooks: {
  ...getHooks(Components),
  PatternViewer: PatternViewerHook,
  "MonsterConstructionWeb.PageHTML.HomeHTML.FadeInObserver": FadeInObserver,
,      // <-- INVALID! Double comma
  LiveSvelteGettextInit
}
```

**Root Cause:** `lib/mix/tasks/live_svelte_gettext.install.ex:398-419` - Regex doesn't handle existing trailing commas

**Solution:**
- Detect if hooks object is empty or has content
- If non-empty: strip trailing commas/whitespace, then add `, LiveSvelteGettextInit`
- If empty: just add `LiveSvelteGettextInit`

**Status:** ✅ FIXED

---

### Issue 3: Missing LiveView Import (FIXED)
**Problem:** `svelte_translations/1` function is undefined in LiveView contexts because `LiveSvelteGettext.Components` is only imported in `:html` function, not `:live_view`

**Error:**
```
error: undefined function svelte_translations/1 (expected MonsterConstructionWeb.PatternViewerSvelteLive to define such a function or for it to be imported, but none are available)
```

**Root Cause:** `lib/mix/tasks/live_svelte_gettext.install.ex:481-488` - Only adds import to `html/0` function

**Solution:** Add import to BOTH `:html` and `:live_view` functions in the web module
- Create separate `add_import_to_html/1` and `add_import_to_live_view/1` helpers
- Call both from `add_component_import/1`

**Status:** ✅ FIXED

---

### Issue 4: Incorrect Module Name Generation (FIXED)
**Problem:** The generated SvelteStrings module name doesn't match what Components expects

**Generated:** `MonsterConstructionWeb.SvelteStrings`
**Expected:** `MonsterConstructionWeb.Gettext.SvelteStrings`

**Root Cause:** `lib/mix/tasks/live_svelte_gettext.install.ex:237-242` - `derive_module_name/1` replaces the last part instead of making it a submodule

```elixir
# Current (WRONG):
backend
|> Module.split()
|> List.replace_at(-1, "SvelteStrings")  # MyAppWeb.Gettext -> MyAppWeb.SvelteStrings
|> Module.concat()

# Should be:
Module.concat(backend, SvelteStrings)  # MyAppWeb.Gettext -> MyAppWeb.Gettext.SvelteStrings
```

**Why this matters:** `lib/live_svelte_gettext/components.ex:147` does:
```elixir
svelte_strings_module = Module.concat(gettext_module, SvelteStrings)
```

**Status:** ✅ FIXED

---

### Issue 5: Compile-Time Warning About Undefined Function
**Problem:** Compile warning about `MonsterConstructionWeb.lgettext/5 is undefined or private`

**Root Cause:** This was a consequence of Issue 4 - the SvelteStrings module had wrong `gettext_backend` reference because the module was in the wrong place

**Status:** ✅ FIXED (resolved by fixing Issue 4)

---

### Issue 6: Nested Objects Break Hook Registration (FIXED)
**Problem:** The regex pattern used to find the hooks object doesn't handle nested braces correctly. When the hooks object contains nested objects (like `...getHooks(Components)` or object literals), the pattern matches the FIRST closing brace instead of the one that actually closes the hooks object.

**Example of failure:**
```javascript
hooks: {
  ...getHooks(Components),  // Has } inside
  PatternViewer: PatternViewerHook,
  FadeInObserver: FadeInObserver,
}
```

**Root Cause:** `lib/mix/tasks/live_svelte_gettext.install.ex:450-472` - The regex `~r/(hooks:\s*\{)([^}]*)(})/s` uses `[^}]*` which means "match anything except `}`", so it stops at the first `}` character it finds (inside `getHooks(Components)`).

**Solution:** Replace regex-based matching with brace-depth tracking:
- Manually parse lines and track opening/closing brace depth
- Start from the line containing `hooks: {`
- Count `{` and `}` characters on each line
- Find the closing brace where depth returns to 0
- Insert the hook before that closing brace

**New Functions Added:**
- `add_hook_to_existing_hooks_object/1` - Handles nested object parsing
- `find_matching_closing_brace/2` - Tracks brace depth to find matching closer

**Status:** ✅ FIXED

---

### Issue 7: Backend Detection Finds Web Modules Instead of Gettext Backends (FIXED)
**Problem:** The `find_gettext_backends` function incorrectly detects web modules that USE Gettext as if they were Gettext backends. This causes the installer to configure the wrong module, leading to `UndefinedFunctionError` when calling `__gettext__/1` on the web module.

**Example of failure:**
```elixir
# config/config.exs (WRONG - generated by buggy installer)
config :live_svelte_gettext, gettext: MonsterConstructionWeb  # ❌ This is a web module, not a Gettext backend!

# Should be:
config :live_svelte_gettext, gettext: MonsterConstructionWeb.Gettext  # ✅ Actual Gettext backend
```

**Error message:**
```
[error] ** (UndefinedFunctionError) function MonsterConstructionWeb.__gettext__/1 is undefined or private
    (monster_construction 0.1.0) MonsterConstructionWeb.__gettext__(:default_locale)
    (live_svelte_gettext 0.1.1) lib/live_svelte_gettext/components.ex:144
```

**Root Cause:** `lib/mix/tasks/live_svelte_gettext.install.ex:140-168` - The detection regex matches BOTH:
- `use Gettext.Backend` (actual backends) ✅
- `use Gettext,` (consumers that use a backend) ❌

**Why this happens:**
Phoenix web modules commonly use Gettext like this:
```elixir
defmodule MyAppWeb do
  def controller do
    quote do
      use Gettext, backend: MyAppWeb.Gettext  # Consumer pattern
    end
  end
end
```

The old code matched this pattern and extracted `MyAppWeb` as a backend, when it should only extract `MyAppWeb.Gettext`.

**Solution:**
- Remove the `|| String.contains?(content, "use Gettext,")` fallback from line 151-152
- Only match `use Gettext.Backend` to find actual Gettext backend definitions
- Add comprehensive tests with fixtures that simulate real Phoenix web modules

**Tests Added:**
- Test with web module consumer + actual backend (should only find backend)
- Test with no Gettext at all (should find nothing)
- Test with multiple backends (should find all backends)

**Status:** ✅ FIXED

---

## Implementation Notes

### Files Modified
- `lib/mix/tasks/live_svelte_gettext.install.ex`:
  - Fixed `add_import_to_js/1` to find last import and made it idempotent
  - Fixed `add_hook_to_livesocket/1` to handle trailing commas and nested objects, made it idempotent
  - Added `add_hook_to_existing_hooks_object/1` to properly handle nested braces
  - Added `find_matching_closing_brace/2` to track brace depth for matching pairs
  - Fixed `derive_module_name/1` to create proper submodule
  - Added `add_import_to_live_view/1` helper
  - Updated `add_component_import/1` to call both helpers and made it idempotent
  - **Fixed `find_gettext_backends/1` to only match actual backends, not consumers**
  - Added test helper functions for unit testing

### Test Files Added
- `test/mix/live_svelte_gettext_install_test.exs`: Comprehensive integration tests (22 test cases, up from 19)
- `test/fixtures/js/app_empty_hooks.js`: Test fixture for empty hooks
- `test/fixtures/js/app_with_hooks.js`: Test fixture for existing hooks
- `test/fixtures/js/app_with_trailing_comma.js`: Test fixture for trailing commas
- `test/fixtures/js/app_with_comment_imports.js`: Test fixture for commented imports
- `test/fixtures/js/app_complex.js`: Test fixture for real-world complex scenario
- `test/fixtures/elixir/test_web_simple.ex`: Test fixture for Phoenix web module
- `test/fixtures/elixir/test_gettext_backend.ex`: Test fixture for Gettext backend
- **`test/fixtures/elixir/test_web_consumer.ex`: Test fixture for web module that uses Gettext (Issue 7)**

### Testing Strategy
1. Test with clean Phoenix project (no existing hooks)
2. Test with existing hooks object (empty)
3. Test with existing hooks object (with content and trailing comma)
4. Test with complex import scenarios (comments, multiple imports)
5. Test with nested objects in hooks (spread operator, object literals)
6. Test that LiveView can use `svelte_translations/1`
7. Test idempotence (running installer multiple times)
8. **Test backend detection with web modules that use Gettext (Issue 7)**
9. **Test backend detection with multiple backends (Issue 7)**
10. **Test backend detection with no backends (Issue 7)**

### Rollout Plan
Since v0.1.1 was just released today and has critical bugs, we will:
1. Revert the v0.1.1 git tag/release
2. Fix all issues
3. Re-release as v0.1.1 (same version, but corrected)
4. Update CHANGELOG.md to document the fixes

## Final Solution

**Approach Change:** Instead of fixing fragile JavaScript regex parsing (Issues 1, 2, 6), we refactored to use manual JavaScript setup with an interactive wizard.

### What We Fixed:

1. **Created `mix live_svelte_gettext.setup`** - Interactive wizard for JavaScript setup
   - Detects app.js location
   - Provides copy-pasteable code snippets
   - Shows context-aware instructions based on existing code
   - Verifies setup status

2. **Removed all JavaScript modification code** - Eliminated 300+ lines of fragile regex
   - Removed `add_import_to_js/1`
   - Removed `add_hook_to_livesocket/1`
   - Removed `add_hook_to_existing_hooks_object/1`
   - Removed `find_matching_closing_brace/2`

3. **Added `use LiveSvelteGettext` to Gettext backend** - Fixed missing functionality
   - New `add_use_to_gettext_backend/1` function
   - Inserts `use LiveSvelteGettext` after `use Gettext.Backend`
   - Idempotent operation

4. **Fixed Elixir Issues:**
   - ✅ Issue 3: Import in both `:html` and `:live_view` functions
   - ✅ Issue 4: Proper submodule naming (`MyApp.Gettext.SvelteStrings`)
   - ✅ Issue 5: No compile warnings (fixed by Issue 4)
   - ✅ Issue 7: Backend detection only finds actual backends

5. **Updated tests** - Removed JS tests, kept Elixir tests
   - 10 tests remaining (down from 22)
   - All tests pass
   - Focused on module naming, imports, and backend detection

6. **Updated documentation:**
   - README.md with new installation flow
   - New setup task moduledoc
   - Updated installer moduledoc

## Acceptance Criteria

- [x] `LiveSvelteGettext.Components` imported in both `:html` and `:live_view` functions
- [x] Generated module name is `#{WebModule}.Gettext.SvelteStrings` (proper submodule)
- [x] No compile warnings about undefined `lgettext/5`
- [x] Backend detection only finds actual Gettext.Backend modules, not consumers
- [x] Config file contains correct Gettext backend module
- [x] `use LiveSvelteGettext` added to Gettext backend
- [x] Interactive setup task created
- [x] All JavaScript modification code removed
- [x] Tests updated and passing (10 tests)
- [x] Documentation updated
- [x] Clean, maintainable solution

## Related
- Blocks: Release v0.1.1
- Part of: P001 (Overall Project Plan)
