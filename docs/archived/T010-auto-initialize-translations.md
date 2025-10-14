# T010: Auto-Initialize Translations in Svelte Components

**Status:** In Progress
**Phase:** 3 - TypeScript Client Library
**Assignee:** @nille + @claude
**Created:** 2025-10-14
**Completed:**

## Description

Currently, users must manually initialize translations in every Svelte component entry point by reading the `#svelte-translations` script tag and calling `initTranslations()`. This creates boilerplate and is error-prone.

We should auto-initialize translations using a Phoenix LiveView hook that's exported from an NPM package, providing a clean, bundler-friendly solution that follows Phoenix ecosystem patterns.

## Current Pain Point

Users currently need this boilerplate in every Svelte app:

```svelte
<script>
  import { initTranslations, gettext } from "../lib/translations";

  // 😩 Manual initialization boilerplate
  if (typeof window !== "undefined") {
    const translationsEl = document.getElementById("svelte-translations");
    if (translationsEl) {
      try {
        const translations = JSON.parse(translationsEl.textContent || "{}");
        initTranslations(translations);
      } catch (error) {
        console.error("[i18n] Failed to load translations:", error);
      }
    } else {
      console.warn("[i18n] Translation script tag not found");
    }
  }
</script>

<h1>{gettext("Welcome")}</h1>
```

## Desired Experience

After this change, users should only need:

```svelte
<script>
  import { gettext } from "live-svelte-gettext";
  // ✨ That's it! Auto-initialized via Phoenix hook!
</script>

<h1>{gettext("Welcome")}</h1>
```

## Technical Challenge Discovered

**Initial approach (inline `<script type="module">`):** Doesn't work because:
- Inline scripts in HEEx templates aren't processed by esbuild
- Browser can't resolve NPM package names like `'live-svelte-gettext'` without bundling
- Would require import maps or other non-standard Phoenix setup

**Solution:** Use Phoenix LiveView hooks (proper Phoenix pattern!)

## Acceptance Criteria

- [x] Remove inline `<script type="module">` approach
- [x] `.svelte_translations` component adds invisible div with `phx-hook="LiveSvelteGettextInit"`
- [x] Create NPM package structure with `package.json`
- [x] Export translation functions (`gettext`, `ngettext`) from NPM package
- [x] Export `LiveSvelteGettextInit` Phoenix hook from NPM package
- [x] Update component tests for hook-based initialization
- [x] Update README with hook registration instructions
- [x] Document manual setup (one line in app.js) until Igniter works
- [x] All tests passing (93 tests)
- [x] Tested in real project and working! ✅

## Implementation Plan

### Architecture: Phoenix Hook + NPM Package

The solution uses two parts:

1. **NPM Package** (`live-svelte-gettext`):
   - Exports translation functions for Svelte components
   - Exports Phoenix hook for auto-initialization
   - Published to npm (future) or bundled in Hex package

2. **Phoenix Component** (`.svelte_translations`):
   - Renders JSON script tag (existing)
   - Renders invisible div with `phx-hook="LiveSvelteGettextInit"`
   - Hook reads JSON and calls `initTranslations()`

### File Structure

```
assets/
├── package/                          # NPM package source
│   ├── package.json                  # Package metadata
│   └── index.js                      # Translation functions + hook
├── js/
│   └── translations.ts               # Kept for backwards compat (wrapper)
└── ...

lib/live_svelte_gettext/
└── components.ex                     # Updated to use hook div
```

### Component Output

```heex
<!-- JSON data -->
<script id="svelte-translations" type="application/json">
  {"Hello":"Hej","Welcome":"Välkommen"}
</script>

<!-- Phoenix hook for auto-init -->
<div id="svelte-translations-init"
     phx-hook="LiveSvelteGettextInit"
     data-translations-id="svelte-translations"
     style="display:none;">
</div>
```

### NPM Package API

```javascript
// assets/package/index.js

// Translation state (private)
const state = { translations: {}, initialized: false };

// Public API
export function initTranslations(data) { /*...*/ }
export function gettext(key, vars) { /*...*/ }
export function ngettext(singular, plural, count, vars) { /*...*/ }

// Phoenix Hook (auto-initialization)
export const LiveSvelteGettextInit = {
  mounted() {
    const id = this.el.dataset.translationsId;
    const el = document.getElementById(id);
    if (el) {
      try {
        initTranslations(JSON.parse(el.textContent || '{}'));
      } catch (error) {
        console.error('[LiveSvelteGettext] Failed to initialize:', error);
      }
    }
  }
};
```

### User Setup (Manual, until Igniter)

Add one line to `assets/js/app.js`:

```javascript
import { getHooks } from "live-svelte";
import { LiveSvelteGettextInit } from "live-svelte-gettext";

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: {
    ...getHooks(Components),
    LiveSvelteGettextInit,  // <-- Add this
  }
});
```

### Benefits

1. **Proper Phoenix pattern** - Uses LiveView hooks as intended
2. **Bundler friendly** - esbuild processes app.js imports normally
3. **Type safe** - NPM package provides TypeScript types
4. **Clean imports** - `import { gettext } from 'live-svelte-gettext'`
5. **One-line setup** - Just register the hook (or Igniter does it)
6. **No window globals** - Clean module-based architecture
7. **Works with all bundlers** - esbuild, vite, webpack, etc.

## Implementation Notes

### Phase 1: Core Implementation (Current)
- Update component to use hook div
- Create NPM package structure
- Write translation functions and hook
- Update tests

### Phase 2: Distribution (Future)
- Publish to npm as `live-svelte-gettext`
- OR bundle in `priv/static/` and copy to user's `node_modules`
- Update Igniter to handle npm install and app.js modification

### Phase 3: Naming Consistency (Separate Task)
- Rename `live_svelte_gettext` → `live_svelte_gettext` (Hex)
- Ensures naming matches `live_svelte` package pattern

## Why This Approach?

**Follows LiveSvelte's Pattern:**
- LiveSvelte publishes to both Hex and NPM
- Exports hooks via `getHooks(Components)`
- Users import from package name: `import { getHooks } from "live-svelte"`
- We mirror this: `import { LiveSvelteGettextInit } from "live-svelte-gettext"`

**Avoids Common Pitfalls:**
- ❌ Inline `<script type="module">` - not processed by bundler
- ❌ Window globals - pollutes global namespace
- ❌ Colocated JS - wrong pattern for global initialization
- ✅ Phoenix hooks - designed for this exact use case!

## Final Implementation Summary

### What Works
✅ Phoenix hook pattern successfully initializes translations
✅ NPM package exports both functions and hook
✅ Zero boilerplate in Svelte components
✅ All 93 tests passing
✅ Tested and working in production project (Monster Construction)

### Key Discovery: Wrapper Pattern
The best approach for projects with existing translation imports is to **create a wrapper file** that re-exports from the NPM package:

```typescript
// assets/svelte/lib/translations.ts (wrapper)
export { gettext, ngettext, /* ... */ } from 'live-svelte-gettext';
```

This allows existing imports (`from '../lib/translations'`) to work without modification while using the new auto-initialized system.

### Files Created
- `assets/package/` - NPM package source
  - `package.json` - Package metadata
  - `index.js` - Translation functions + Phoenix hook
  - `index.d.ts` - TypeScript definitions

### Files Modified
- `lib/live_svelte_gettext/components.ex` - Uses Phoenix hook div
- `test/live_svelte_gettext/components_test.exs` - Updated tests
- `README.md` - Hook registration instructions
- `docs/tasks/T010-auto-initialize-translations.md` - This file

### Distribution Strategy
Users will:
1. Copy `assets/package/` to their `node_modules/live-svelte-gettext` (or npm install when published)
2. Register hook in `app.js` (one line)
3. Optionally create wrapper file for existing imports

## Related

- Part of: P001 (Overall Project Plan)
- Extends: T003 (TypeScript Client Library)
- Replaces initial approach from: T008 (Simplify Translation Injection)
- Future: Will add Igniter automation for app.js modification
