# T001: Phase 1 - Core Extraction Engine

**Status:** In Progress
**Phase:** 1 - Core Extraction Engine
**Assignee:**
**Created:** 2025-10-14
**Completed:**

## Description

Build the Svelte string extraction logic that scans `.svelte` files and extracts translation strings from `gettext()` and `ngettext()` calls.

This is the foundation of the entire library - it needs to handle all edge cases correctly.

## Acceptance Criteria

- [x] `LiveSvelteGettext.Extractor` module created
- [x] Extract `gettext("string")` calls
- [x] Extract `gettext("string", %{vars})` with interpolation
- [x] Extract `ngettext("singular", "plural", count)` calls
- [x] Handle single and double quotes
- [x] Handle escaped quotes (e.g., `\"` and `\'`)
- [x] Track file:line metadata for each extraction
- [x] Deduplication logic (group by msgid, preserve all references)
- [x] Comprehensive test suite with fixtures
  - [x] Unit tests for regex patterns
  - [x] Integration tests with fixture Svelte files
  - [x] Edge cases (multiline, comments, nested strings)
- [x] Test coverage > 90% (achieved 100%)

## Implementation Notes

### Completed Implementation (2025-10-14)

**Module:** `lib/livesvelte_gettext/extractor.ex`

#### Regex Patterns Used:

1. **gettext pattern:**
   ```regex
   /gettext\s*\(\s*(['"])([^\1]*?(?:\\.[^\1]*?)*)\1(?:\s*,\s*\{[^}]*\})?\s*\)/
   ```
   - Handles both single and double quotes
   - Captures escaped characters
   - Optional interpolation object `{...}`

2. **ngettext pattern:**
   ```regex
   /ngettext\s*\(\s*(['"])([^\1]*?(?:\\.[^\1]*?)*)\1\s*,\s*(['"])([^\3]*?(?:\\.[^\3]*?)*)\3\s*,/
   ```
   - Matches two quoted strings (singular, plural)
   - Handles mixed quote types

#### Key Design Decisions:

1. **Unescaping:** Used `String.replace/3` with a 1-arity function to properly handle escape sequences
2. **Comment Filtering:** Removed HTML comments before extraction to avoid false matches
3. **Line Tracking:** Used `String.split("\n")` with `Enum.with_index(1)` for accurate line numbers
4. **Deduplication:** Group by `{msgid, type, plural}` tuple, merge all references

#### Test Coverage:

- **Total:** 28 tests (including 1 doctest)
- **Coverage:** 100%
- **Test files:**
  - `test/livesvelte_gettext/extractor_test.exs` (21 unit tests)
  - `test/integration/fixtures_test.exs` (6 integration tests)
- **Fixtures created:**
  - `test/fixtures/UserProfile.svelte` (realistic user profile component)
  - `test/fixtures/ShoppingCart.svelte` (conditional rendering, plurals)
  - `test/fixtures/ErrorMessages.svelte` (special characters, escaping)

#### Edge Cases Handled:

- Escaped quotes (`\"`, `\'`)
- Backslashes (`\\`)
- Mixed quote types on same line
- Multiple calls per line
- Whitespace variations
- HTML comments (excluded)
- Empty files
- Special characters (©, UTF-8)
- Variable interpolation syntax

#### Performance Notes:

- Line-by-line regex scanning (efficient for typical file sizes)
- Single pass for each pattern type
- Deduplication happens after extraction (memory efficient)

## Related

- Part of: P001 (Overall Project Plan)
- Blocks: T002 (Compiler needs Extractor output)
