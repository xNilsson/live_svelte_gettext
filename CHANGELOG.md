# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

- **Igniter installer** (`mix igniter.install livesvelte_gettext`)
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

[0.1.0]: https://github.com/xnilsson/livesvelte_gettext/releases/tag/v0.1.0
