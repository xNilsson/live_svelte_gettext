# T003: Phase 3 - TypeScript Client Library

**Status:** Not Started
**Phase:** 3 - TypeScript Client Library
**Assignee:**
**Created:** 2025-10-14
**Completed:**

## Description

Create a type-safe TypeScript library for Svelte components to use at runtime. This receives translations from the server and provides `gettext()` and `ngettext()` functions in JavaScript.

## Acceptance Criteria

- [ ] `assets/js/translations.ts` created
- [ ] `initTranslations(data)` function for loading server data
- [ ] `gettext(key, vars?)` function with interpolation
- [ ] `ngettext(singular, plural, count, vars?)` function
- [ ] Variable interpolation (`%{var}` syntax)
- [ ] Proper handling of missing translations (fallback to key)
- [ ] Utility functions: `isInitialized()`, `resetTranslations()`
- [ ] Full TypeScript type definitions
- [ ] Vitest test suite
  - [ ] Initialization tests
  - [ ] gettext tests (simple, interpolation, missing)
  - [ ] ngettext tests (singular/plural, additional vars)
  - [ ] Edge cases (special characters, regex escaping)
- [ ] Test coverage > 90%
- [ ] `package.json` configuration for npm publishing
- [ ] TypeScript build setup (`tsconfig.json`)
- [ ] README for the npm package

## Implementation Notes

Core functions:
```typescript
initTranslations(data: Record<string, string>): void
gettext(key: string, vars?: Record<string, string | number>): string
ngettext(singular: string, plural: string, count: number, vars?): string
```

Interpolation:
- Replace `%{varname}` with values
- Need to escape regex special chars in variable names
- Handle missing variables gracefully

Plural rules:
- Start simple: English rules (count === 1 ? singular : plural)
- Note for future: proper CLDR plural rules for v0.2.0

Testing:
- Use Vitest (modern, fast)
- Mock translation data
- Test edge cases thoroughly
- Test that Swedish characters work (åäö)

Build setup:
- TypeScript → ESM output
- Declaration files (.d.ts)
- Package for both direct import and npm publish

## Related

- Part of: P001 (Overall Project Plan)
- Independent (can be built in parallel with T002)
