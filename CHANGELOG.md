# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2025-10-14

### Fixed

- **Igniter installer critical bug fixes** (7 issues resolved)
  - Fixed backend detection to only find actual `Gettext.Backend` modules, not consumers (Issue #7)
  - Fixed module naming to create proper submodule `MyApp.Gettext.SvelteStrings` (Issue #4)
  - Fixed missing `use LiveSvelteGettext` in Gettext backend (previously undiscovered issue)
  - Fixed component import to be added to both `:html` and `:live_view` functions (Issue #3)
  - Eliminated all compile warnings about undefined functions (Issue #5)
- **Fixed translation initialization race condition**
  - Phoenix hook `mounted()` callback sometimes doesn't fire before Svelte components call `gettext()`
  - Implemented lazy initialization - translations now auto-initialize on first use
  - Completely removed Phoenix hook requirement for simpler setup

### Changed

- **Refactored JavaScript setup to manual process** (Issues #1, #2, #6 resolution)
  - Removed 300+ lines of fragile regex-based JavaScript modification code
  - JavaScript setup now uses interactive `mix live_svelte_gettext.setup` wizard
  - Users get clear, copy-pasteable code snippets based on their project structure
  - More reliable across different JavaScript formatting styles and project setups
  - Follows Elixir ecosystem best practices (explicit over implicit)
- **Phoenix hook completely removed**
  - Zero JavaScript setup required - just install the NPM package
  - Translations automatically initialize on first `gettext()` or `ngettext()` call
  - Simpler API with less cognitive overhead for users
  - Updated all documentation to remove hook references

### Added

- **Interactive setup wizard** (`mix live_svelte_gettext.setup`)
  - Detects `app.js` location automatically
  - Analyzes existing code structure and hooks
  - Provides context-aware, copy-pasteable instructions
  - Verifies setup status and completion
  - Supports multiple project structures (empty hooks, existing hooks, nested objects, etc.)
- **Automated `use LiveSvelteGettext` injection**
  - Installer now adds `use LiveSvelteGettext` to your Gettext backend module
  - Properly configured with backend reference and Svelte path
  - Idempotent operation (safe to run multiple times)
- **Improved Elixir component import**
  - Now adds `import LiveSvelteGettext.Components` to both `:html` and `:live_view` functions
  - Ensures `svelte_translations/1` is available in LiveView contexts
  - Idempotent operation
- **Lazy initialization for translations** (`ensureInit()`)
  - Translations automatically initialize from DOM on first use
  - Eliminates need for Phoenix hook registration entirely
  - Works in all environments with zero configuration
  - Added comprehensive test coverage for lazy initialization (6 new tests)
  - Supports SSR and all edge cases

### Removed

- **Phoenix LiveView hook requirement**
  - `LiveSvelteGettextInit` hook no longer needed or exported
  - Removed hook element from `<.svelte_translations />` component
  - No more hook registration setup step
- **Automatic JavaScript modification code** (replaced with simplified setup guide)
  - `add_import_to_js/1` function
  - `add_hook_to_livesocket/1` function
  - `add_hook_to_existing_hooks_object/1` function
  - `find_matching_closing_brace/2` function
  - All JavaScript-related test fixtures and tests (12 tests removed, 10 Elixir tests remain)
  - Interactive setup wizard functions (replaced with simple informational task)

### Architecture

This release represents a significant architectural improvement:

**Before v0.1.1:**
- Attempted to automatically modify JavaScript using regex patterns
- Fragile across different formatting styles and project structures
- Hard to debug and maintain
- 7 critical bugs in JavaScript parsing logic

**After v0.1.1:**
- Clean separation: Igniter handles Elixir, setup wizard handles JavaScript
- Users have full visibility into changes being made
- More reliable and easier to maintain
- Follows patterns used by successful libraries like `live_svelte`

### Migration

If you installed an earlier version of v0.1.1 (released 2025-10-14 morning):

1. The JavaScript modifications may have errors - manually verify `assets/js/app.js`
2. Run `mix live_svelte_gettext.setup` to get correct setup instructions
3. Your Elixir-side setup should be correct and requires no changes

For most users, simply run:
```bash
mix deps.update live_svelte_gettext
mix live_svelte_gettext.setup
```

## [0.1.0] - 2025-10-14

### Added

- **Core compile-time extraction engine** (`LiveSvelteGettext.Extractor`)
  - Scans `.svelte` files for `gettext()` and `ngettext()` calls
  - Supports both single and double quotes
  - Handles escaped characters properly
  - Extracts file and line number references for debugging
  - Deduplicates strings across multiple files

- **Compile-time code generation** (`LiveSvelteGettext.Compiler`)
  - Generates Elixir `gettext()` and `ngettext()` calls for extraction
  - Creates runtime `all_translations/1` function
  - Sets up `@external_resource` for automatic recompilation
  - Provides `__lsg_metadata__/0` debug function
  - Validates configuration options at compile time

- **NPM package** (`live-svelte-gettext`)
  - `gettext()` - Simple translations with interpolation
  - `ngettext()` - Plural form handling
  - `initTranslations()` - Initialize with server data (called automatically)
  - `isInitialized()` - Check initialization status
  - `resetTranslations()` - Reset state (for testing)
  - `LiveSvelteGettextInit` - Phoenix LiveView hook for auto-initialization
  - Full TypeScript type safety with `.d.ts` definitions
  - Variable interpolation with `%{name}` syntax
  - Count-based pluralization

- **Phoenix component** (`.svelte_translations`)
  - Injects translations as JSON script tag
  - Renders invisible div with `phx-hook="LiveSvelteGettextInit"`
  - Auto-initializes translations via Phoenix LiveView hook
  - Zero manual setup required in Svelte components

- **Igniter installer** (`mix igniter.install live_svelte_gettext`)
  - Automatic Gettext backend detection
  - Automatic Svelte directory detection
  - Creates `SvelteStrings` module with correct configuration
  - Copies TypeScript library to assets directory
  - Provides clear usage instructions
  - Supports manual configuration via CLI flags

- **Comprehensive documentation**
  - Module documentation with examples
  - Function documentation with type specs
  - README with quick start guide
  - Architecture diagrams
  - Troubleshooting section
  - Contributing guidelines

- **Testing infrastructure**
  - Unit tests for extraction engine
  - Unit tests for compiler
  - Unit tests for TypeScript library
  - Test fixtures for realistic scenarios
  - ExCoveralls integration for coverage reporting

### Features

- Zero-maintenance workflow - no generated files to commit
- Automatic recompilation when Svelte files change
- Works with existing `mix gettext.extract` and `mix gettext.merge` workflows
- Full integration with Elixir's Gettext library
- Type-safe TypeScript client
- One-command installation
- Supports variable interpolation in translations
- Supports plural forms

### Technical Details

- Elixir 1.18+ required
- Compatible with Gettext 0.24+
- Uses `@external_resource` for automatic recompilation
- Uses macro-generated AST (no runtime overhead)
- Client library has zero dependencies
- Follows Elixir and TypeScript best practices

## [Unreleased]

### Planned

- Advanced CLDR plural rules support
- Context-aware translations (pgettext)
- Translation extraction from TypeScript/JavaScript files
- VS Code extension for translation management
- Translation coverage reporting

---

[0.1.1]: https://github.com/xnilsson/live_svelte_gettext/releases/tag/v0.1.1
[0.1.0]: https://github.com/xnilsson/live_svelte_gettext/releases/tag/v0.1.0
