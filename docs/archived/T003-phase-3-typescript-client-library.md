# T003: Phase 3 - TypeScript Client Library

**Status:** Done
**Phase:** 3 - TypeScript Client Library
**Assignee:**
**Created:** 2025-10-14
**Completed:** 2025-10-14

## Description

Create a type-safe TypeScript library for Svelte components to use at runtime. This receives translations from the server and provides `gettext()` and `ngettext()` functions in JavaScript.

## Acceptance Criteria

- [x] `assets/js/translations.ts` created
- [x] `initTranslations(data)` function for loading server data
- [x] `gettext(key, vars?)` function with interpolation
- [x] `ngettext(singular, plural, count, vars?)` function
- [x] Variable interpolation (`%{var}` syntax)
- [x] Proper handling of missing translations (fallback to key)
- [x] Utility functions: `isInitialized()`, `resetTranslations()`
- [x] Full TypeScript type definitions
- [x] Vitest test suite
  - [x] Initialization tests
  - [x] gettext tests (simple, interpolation, missing)
  - [x] ngettext tests (singular/plural, additional vars)
  - [x] Edge cases (special characters, regex escaping)
- [x] Test coverage > 90% (achieved 100%)
- [x] `package.json` configuration for npm publishing
- [x] TypeScript build setup (`tsconfig.json`)
- [x] README for the npm package

## Implementation Notes

### Completed Implementation (2025-10-14)

**Module:** `assets/js/translations.ts` (234 lines)

#### Core Functions Implemented:

```typescript
initTranslations(data: Record<string, string>): void
isInitialized(): boolean
resetTranslations(): void
gettext(key: string, vars?: Record<string, string | number>): string
ngettext(singular: string, plural: string, count: number, vars?): string
```

**Internal helpers:**
- `escapeRegExp(str)` - Escapes regex special chars for safe variable replacement
- `interpolate(text, vars)` - Handles `%{var}` substitution

#### Key Implementation Details:

1. **State Management:**
   - Private `translations` object stores key-value pairs
   - Private `initialized` flag tracks initialization state
   - `resetTranslations()` clears state (useful for testing)

2. **Variable Interpolation:**
   - Regex pattern: `/\%\{${escapedKey}\}/g`
   - Escapes special regex chars in variable names (handles `var.name`, `var[0]`, etc.)
   - Gracefully handles missing variables (leaves placeholder intact)
   - Supports both string and number values
   - Replaces all occurrences of same variable

3. **Plural Rules:**
   - Simple English rules: `count === 1 ? singular : plural`
   - Always includes `count` in interpolation vars
   - User-provided vars merged with count (vars can override)

4. **Fallback Behavior:**
   - Missing translations return the key itself
   - Interpolation still works on fallback keys
   - No errors thrown (graceful degradation)

#### Test Coverage:

**File:** `assets/js/translations.test.ts` (392 lines)
**Test suites:** 8 describe blocks
**Total tests:** 48 test cases
**Coverage:** 100% (statements, branches, functions, lines)

**Test categories:**
1. Initialization (4 tests)
2. isInitialized (3 tests)
3. resetTranslations (2 tests)
4. gettext simple (3 tests)
5. gettext interpolation (8 tests)
6. gettext missing translations (2 tests)
7. gettext edge cases (7 tests)
8. ngettext plural rules (6 tests)
9. ngettext with vars (4 tests)
10. ngettext missing translations (3 tests)
11. ngettext edge cases (3 tests)
12. TypeScript types (3 tests)

**Edge cases tested:**
- Swedish characters (åäö)
- Special characters (!@#$%^&*...)
- Quotes (single, double)
- Newlines
- Empty strings
- Regex special chars in variable names (`.`, `$`, `[`, etc.)
- Multiple occurrences of same variable
- Malformed placeholders
- Negative numbers
- Decimal numbers
- Missing variables
- Extra variables

#### Build Configuration:

**TypeScript:** `assets/tsconfig.json`
- Target: ES2020
- Module: ESNext
- Strict mode enabled
- Declaration files (.d.ts) generated
- Source maps enabled

**Vitest:** `assets/vitest.config.ts`
- Coverage provider: v8
- Coverage thresholds: 90% (all metrics)
- Node environment

**Package:** `assets/package.json`
- Name: live-svelte-gettext
- Version: 0.1.0
- Type: module (ESM)
- Main: ./dist/translations.js
- Types: ./dist/translations.d.ts
- Dependencies: vitest@^2.1.8, typescript@^5.7.2, @vitest/coverage-v8@^2.1.8

**Build artifacts generated:**
- `dist/translations.js` (3.8 KB)
- `dist/translations.d.ts` (2.5 KB)
- `dist/translations.js.map` (1.6 KB)
- `dist/translations.d.ts.map` (657 B)

#### Documentation:

**README:** `assets/README.md` (comprehensive)
- Quick start guide
- API reference with examples
- Usage in Svelte components
- Integration with Phoenix LiveView
- TypeScript type information
- Testing instructions
- Edge cases documentation
- Browser support info

#### Quality Metrics:

- **Lines of code:** 234 (implementation) + 392 (tests) = 626 total
- **Test coverage:** 100%
- **Test count:** 48 tests, all passing
- **Build time:** ~200ms
- **Bundle size:** 3.8 KB (unminified)
- **Zero runtime dependencies**

#### Notes for T004 (Igniter Installer):

The Igniter installer will need to:
1. Copy `assets/js/translations.ts` to user's project
2. Or install via npm: `npm install live-svelte-gettext-client`
3. Import path: `import { initTranslations, gettext, ngettext } from './translations'`

## Related

- Part of: P001 (Overall Project Plan)
- Independent (can be built in parallel with T002)
