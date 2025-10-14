# Task T009: Fix __BINDING__ Placeholder in Translations

## Status
**Completed** - 2025-01-14

## Problem

When using variable interpolation in Svelte translation strings, the translated values in `.po` files contain `__BINDING__` placeholders instead of the actual variable names like `%{min}` and `%{max}`.

### Current Behavior

**Svelte source code:**
```svelte
{gettext("Range: %{min}–%{max} mm", { min: minValue, max: maxValue })}
```

**Translation in `.po` file:**
```po
msgid "Range: %{min}–%{max} mm"
msgstr "Område: __BINDING__–__BINDING__ mm"
```

**Result on website:**
```
Område: __BINDING__–__BINDING__ mm
```

### Expected Behavior

**Translation in `.po` file should be:**
```po
msgid "Range: %{min}–%{max} mm"
msgstr "Område: %{min}–%{max} mm"
```

**Result on website should be:**
```
Område: 34–42 mm
```

## Root Cause

The issue appears to be in the Svelte string extraction process. When the extractor encounters variable interpolation in Svelte templates, it's replacing the variable expressions with `__BINDING__` placeholders.

### Hypothesis

The extractor might be processing the Svelte template's reactive bindings (`{min}`, `{max}`) and converting them to `__BINDING__` before recognizing the `%{min}` and `%{max}` patterns in the translation string.

This could happen if:

1. The Svelte parser is replacing all `{...}` expressions with `__BINDING__` before extraction
2. The pattern matching for `gettext()` calls happens after this substitution
3. The `%{varname}` patterns get caught in this replacement

## Investigation Needed

1. **Check the Extractor module** (`lib/live_svelte_gettext/extractor.ex`)
   - How does it parse Svelte files?
   - When does it replace template expressions with `__BINDING__`?
   - Is this replacement too aggressive?

2. **Check extraction test cases**
   - Do we have test coverage for interpolated variables?
   - What do the tests expect?

3. **Review Svelte template parsing**
   - How are we distinguishing between:
     - Svelte template bindings: `{variableName}`
     - Gettext interpolation markers: `%{variableName}`

## Potential Solutions

### Option 1: Preserve %{} Patterns During Extraction

Modify the extractor to preserve `%{varname}` patterns even when replacing other Svelte bindings:

```elixir
# In extractor.ex
defp replace_bindings(text) do
  # Don't replace bindings that are inside %{...} patterns
  # This requires more sophisticated parsing
  text
  |> preserve_gettext_interpolation()
  |> replace_svelte_bindings()
end
```

### Option 2: Extract Before Template Processing

Extract `gettext()` calls before doing any template binding replacement:

```elixir
# Extract translation calls first
extractions = extract_gettext_calls(content)

# Then process template bindings for other purposes
processed_content = replace_bindings(content)
```

### Option 3: Use Different Placeholder Pattern

If Svelte bindings must be replaced before extraction, use a pattern that won't conflict:

```elixir
# Replace Svelte bindings but preserve gettext interpolation
def replace_bindings(text) do
  text
  |> String.replace(~r/\{(?!%)(.*?)\}/, "__SVELTE_BINDING__")
  # This regex avoids matching {%...} patterns
end
```

## Test Cases Needed

Add tests for interpolated translation strings:

```elixir
test "extracts gettext calls with variable interpolation" do
  svelte_content = """
  <script>
    import { gettext } from './translations.ts'
    let min = 10
    let max = 20
  </script>

  <p>{gettext("Range: %{min}–%{max} mm", { min, max })}</p>
  """

  {:ok, extractions} = Extractor.extract_from_content(svelte_content, "test.svelte")

  assert [
    {msgid: "Range: %{min}–%{max} mm", line: 7}
  ] = extractions

  # Verify that %{min} and %{max} are preserved
  [extraction] = extractions
  assert extraction.msgid =~ "%{min}"
  assert extraction.msgid =~ "%{max}"
  refute extraction.msgid =~ "__BINDING__"
end
```

## Files to Review

- `lib/live_svelte_gettext/extractor.ex` - Main extraction logic
- `lib/live_svelte_gettext/compiler.ex` - Code generation
- `test/live_svelte_gettext/extractor_test.exs` - Test coverage
- Example Svelte files in test fixtures

## Success Criteria

- [x] Identified root cause of `__BINDING__` replacement
- [x] Fixed compiler to preserve `%{varname}` patterns
- [x] Added test coverage for interpolated variables
- [x] Verified fix with real-world Svelte components
- [x] Updated documentation if necessary
- [x] All existing tests still pass

## Implementation Summary

### Root Cause
The bug was in `lib/live_svelte_gettext/compiler.ex`, specifically in the `all_translations/1` function. The function was creating dummy bindings like `%{name: "__BINDING__"}` and passing them to `Gettext.dgettext()`, which caused Gettext's interpolation engine to substitute `%{name}` patterns with the string `"__BINDING__"` in the returned translations.

### Solution
**For gettext():**
- Pass an empty bindings map `%{}` to `backend.lgettext()` instead of dummy bindings
- Handle the `{:missing_bindings, str, keys}` return tuple to extract the raw msgstr
- This preserves `%{varname}` patterns in the translation strings sent to the frontend

**For ngettext():**
- Return the raw `msgid` and `msgid_plural` directly from extractions
- Avoids calling `lngettext()` which automatically adds `:count` binding
- Frontend handles interpolation at runtime with actual values

### Files Changed
- `lib/live_svelte_gettext/compiler.ex:236-277` - Fixed `all_translations/1` function
- `test/integration/full_compile_test.exs:80-103` - Added comprehensive test coverage

### Trade-offs
For non-English locales, plural translations currently return the English msgid/msgid_plural. A future enhancement could parse `.po` files directly to support localized plural forms while still avoiding interpolation.

## Related Issues

This is a critical bug that affects the primary use case of the library: translating user-facing strings with dynamic values.

## Priority

**High** - This breaks a core feature (variable interpolation) and makes translations unusable for strings with dynamic content.

## Notes

The `translations.ts` client library correctly handles interpolation (uses `%{varname}` patterns), so this is purely an extraction/server-side issue.
