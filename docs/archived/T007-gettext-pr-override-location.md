# T007: Gettext PR - Add `:override_location` Support

**Status:** Postponed
**Priority:** Low (Nice to have, not blocking)
**Created:** 2025-10-14
**Postponed:** 2025-10-14
**Assignee:**
**Completed:**

## Status Update: Why Postponed

After successfully implementing and testing the `CustomExtractor` solution in T006, we've decided to **postpone this task indefinitely** for the following reasons:

### Our Solution Works Perfectly

The `CustomExtractor` approach (modifying `Macro.Env` before calling `Gettext.Extractor.extract/6`) is:
- ✅ **Simple** - Only 15 lines of code
- ✅ **Stable** - `Macro.Env` structure is unlikely to change
- ✅ **Self-contained** - No external dependencies
- ✅ **Production-ready** - Verified with 157 references in Monster Construction project
- ✅ **Works today** - No waiting for upstream releases

### Limited Community Impact

This is a **niche problem** that only affects:
- Compile-time extraction from non-Elixir template sources
- Libraries bridging Elixir gettext with other templating systems
- Estimated 2-5 libraries in the entire Elixir ecosystem (Surface, Temple, etc.)

Most templating libraries use runtime extraction, not compile-time, so they don't face this issue.

### Cost-Benefit Analysis

**Costs of pursuing upstream PR:**
- ⏱️ **Time investment:** 6-10 weeks of discussion, implementation, and review
- 🤷 **Uncertain acceptance:** Gettext maintainers may view this as too niche
- 📦 **Version compatibility:** Would need to support both approaches for years
- 🔧 **Ongoing maintenance:** Track Gettext versions, handle breaking changes

**Benefits:**
- Slightly cleaner code (no CustomExtractor module)
- "Official" solution documented
- Shows we're good Elixir citizens

**Verdict:** The ROI doesn't justify the time investment when we have other priorities.

### When to Revisit

This task should be reconsidered if:
- ✅ Multiple other libraries ask "How did you solve the reference problem?"
- ✅ Surface UI or other libraries implement similar patterns and want to collaborate
- ✅ Gettext maintainers express interest in the issue tracker
- ✅ We have spare time after LiveSvelteGettext v1.0 is stable and adopted

### Documentation Instead of PR

We've added a "For Library Authors" section to the README documenting our pattern. This provides value to the community without the overhead of maintaining an upstream PR.

Any library facing the same problem can copy our approach from `lib/livesvelte_gettext/custom_extractor.ex`.

---

## Original Description

Propose and implement a PR to the upstream Gettext library to add official support for overriding source file locations during extraction. This would make LiveSvelteGettext's reference tracking a first-class feature instead of requiring workarounds.

**Current Workaround:** We modify `Macro.Env` structs before passing them to `Gettext.Extractor.extract/6` (see `LiveSvelteGettext.CustomExtractor`).

**Proposed Solution:** Add an optional `:override_location` parameter to `Gettext.Extractor.extract/6` that allows macro-generated code to specify custom source locations.

## Use Case

Any library that generates `gettext()` calls at compile time faces the same problem:
- All translations appear to come from the macro invocation line
- POT files lose visibility into actual source locations
- Translation tools that rely on accurate references break

**Benefits for Elixir Ecosystem:**
- Enables accurate references for macro-generated translations
- Makes compile-time i18n patterns more viable
- Improves interoperability with standard Gettext tooling
- Documents official way to handle this use case

## Proposed Changes to Gettext

### 1. Modify `Gettext.Extractor.extract/6`

**File:** `lib/gettext/extractor.ex`

**Current signature (line 71-78):**
```elixir
@spec extract(
        Macro.Env.t(),
        backend :: module,
        domain :: binary | :default,
        msgctxt :: binary,
        id :: binary | {binary, binary},
        extracted_comments :: [binary]
      ) :: :ok
def extract(%Macro.Env{} = caller, backend, domain, msgctxt, id, extracted_comments) do
```

**Proposed signature:**
```elixir
@spec extract(
        Macro.Env.t(),
        backend :: module,
        domain :: binary | :default,
        msgctxt :: binary,
        id :: binary | {binary, binary},
        extracted_comments :: [binary],
        opts :: keyword()
      ) :: :ok
def extract(%Macro.Env{} = caller, backend, domain, msgctxt, id, extracted_comments, opts \\ []) do
```

**Proposed implementation (lines 79-99):**
```elixir
def extract(%Macro.Env{} = caller, backend, domain, msgctxt, id, extracted_comments, opts \\ []) do
  format_flag = backend.__gettext__(:interpolation).message_format()

  domain =
    case domain do
      :default -> backend.__gettext__(:default_domain)
      string when is_binary(string) -> string
    end

  # NEW: Allow override of file/line from options
  {file, line} =
    case Keyword.get(opts, :override_location) do
      {override_file, override_line} when is_binary(override_file) and is_integer(override_line) ->
        {override_file, override_line}
      nil ->
        {caller.file, caller.line}
    end

  message =
    create_message_struct(
      id,
      msgctxt,
      file,   # Now respects override
      line,   # Now respects override
      extracted_comments,
      format_flag
    )

  ExtractorAgent.add_message(backend, domain, message)
end
```

### 2. Update `Gettext.Macros` helpers (optional but recommended)

**File:** `lib/gettext/macros.ex`

Make the internal helper functions accept and pass through options:

**Current (line 593-611):**
```elixir
defp extract_singular_translation(env, backend, domain, msgctxt, msgid) do
  backend = expand_backend(backend, env)
  domain = expand_domain(domain, env)
  msgid = expand_to_binary(msgid, "msgid", env)
  msgctxt = expand_to_binary(msgctxt, "msgctxt", env)

  if Extractor.extracting?() do
    Extractor.extract(
      env,
      backend,
      domain,
      msgctxt,
      msgid,
      get_and_flush_extracted_comments()
    )
  end

  msgid
end
```

**Proposed:**
```elixir
defp extract_singular_translation(env, backend, domain, msgctxt, msgid, opts \\ []) do
  backend = expand_backend(backend, env)
  domain = expand_domain(domain, env)
  msgid = expand_to_binary(msgid, "msgid", env)
  msgctxt = expand_to_binary(msgctxt, "msgctxt", env)

  if Extractor.extracting?() do
    Extractor.extract(
      env,
      backend,
      domain,
      msgctxt,
      msgid,
      get_and_flush_extracted_comments(),
      opts  # NEW: Pass through options
    )
  end

  msgid
end
```

Similarly update `extract_plural_translation/6` to accept and forward `opts`.

### 3. Add Documentation

**File:** `lib/gettext/extractor.ex`

Update the `@doc` for `extract/6`:

```elixir
@doc """
Extracts a message by temporarily storing it in an agent.

Note that this function doesn't perform any operation on the filesystem.

## Options

  * `:override_location` - A tuple `{file, line}` to use instead of the
    caller's location. This is useful for libraries that generate gettext
    calls at compile time and want to preserve the original source location.
    For example:

        Gettext.Extractor.extract(
          env,
          MyApp.Gettext,
          "default",
          nil,
          "Hello",
          [],
          override_location: {"assets/components/Button.svelte", 42}
        )

    When extraction runs, the POT file will reference `assets/components/Button.svelte:42`
    instead of the macro expansion site.

"""
```

### 4. Add Tests

**File:** `test/gettext/extractor_test.exs`

```elixir
test "extract/7 with :override_location option" do
  # Enable extraction
  Extractor.enable()

  # Create a fake env
  env = %Macro.Env{
    file: "lib/my_app/macro.ex",
    line: 10,
    module: MyApp.Gettext
  }

  # Extract with override
  :ok = Extractor.extract(
    env,
    MyApp.Gettext,
    "default",
    nil,
    "Test message",
    [],
    override_location: {"assets/svelte/Button.svelte", 42}
  )

  # Get extracted messages
  pot_files = Extractor.pot_files(:my_app, [])

  # Verify the reference points to the overridden location
  assert Enum.any?(pot_files, fn {_path, content} ->
    content =~ "assets/svelte/Button.svelte:42"
  end)

  Extractor.disable()
end

test "extract/7 without :override_location falls back to caller location" do
  Extractor.enable()

  env = %Macro.Env{
    file: "lib/my_app/macro.ex",
    line: 10,
    module: MyApp.Gettext
  }

  # Extract without override
  :ok = Extractor.extract(
    env,
    MyApp.Gettext,
    "default",
    nil,
    "Test message",
    []
  )

  pot_files = Extractor.pot_files(:my_app, [])

  # Verify the reference points to the caller location
  assert Enum.any?(pot_files, fn {_path, content} ->
    content =~ "lib/my_app/macro.ex:10"
  end)

  Extractor.disable()
end
```

## How LiveSvelteGettext Would Use This

Once the PR is merged and released, we can update our compiler:

**File:** `lib/livesvelte_gettext/compiler.ex`

```elixir
defp generate_extraction_calls(extractions) do
  if supports_override_location?() do
    generate_with_native_override(extractions)
  else
    generate_with_custom_extractor(extractions)
  end
end

defp supports_override_location?() do
  # Check if Gettext version supports :override_location
  function_exported?(Gettext.Extractor, :extract, 7)
end

defp generate_with_native_override(extractions) do
  quote do
    if Gettext.Extractor.extracting?() do
      unquote(
        Enum.flat_map(extractions, fn extraction ->
          Enum.flat_map(extraction.references, fn {file, line} ->
            case extraction.type do
              :gettext ->
                [
                  quote do
                    Gettext.Extractor.extract(
                      __ENV__,
                      __MODULE__,
                      :default,
                      nil,
                      unquote(extraction.msgid),
                      [],
                      override_location: {unquote(file), unquote(line)}
                    )
                  end
                ]

              :ngettext ->
                [
                  quote do
                    Gettext.Extractor.extract(
                      __ENV__,
                      __MODULE__,
                      :default,
                      nil,
                      {unquote(extraction.msgid), unquote(extraction.plural)},
                      [],
                      override_location: {unquote(file), unquote(line)}
                    )
                  end
                ]
            end
          end)
        end)
      )
    end
  end
end

defp generate_with_custom_extractor(extractions) do
  # Fallback to our CustomExtractor for older Gettext versions
  # (existing implementation)
end
```

## PR Proposal Draft

**Title:** Add `:override_location` option to `Gettext.Extractor.extract/6`

**Description:**

This PR adds an optional `:override_location` parameter to `Gettext.Extractor.extract/6` to support libraries that generate `gettext()` calls at compile time via macros.

### Problem

When a macro generates multiple `gettext()` calls, all extracted messages reference the macro invocation line, not the original source locations. For example:

```elixir
# lib/my_app_web/svelte_strings.ex:39
use LiveSvelteGettext  # <-- All 126 strings reference this line

# In POT file:
#: lib/my_app_web/svelte_strings.ex:39
msgid "Save Profile"

#: lib/my_app_web/svelte_strings.ex:39
msgid "Delete Account"
```

This breaks workflows that rely on accurate source references, such as:
- Translation tools like `poflow` that update source files
- Developer context when reviewing translations
- Finding where strings are actually used

### Solution

Add an `:override_location` option that allows macro authors to specify custom source locations:

```elixir
Gettext.Extractor.extract(
  env,
  backend,
  "default",
  nil,
  "Save Profile",
  [],
  override_location: {"assets/svelte/Button.svelte", 42}
)
```

This produces POT files with accurate references:

```
#: assets/svelte/Button.svelte:42
msgid "Save Profile"
```

### Benefits

- **Backward compatible:** Existing code works unchanged
- **Opt-in:** Only used when explicitly needed
- **Ecosystem-wide:** Benefits any library doing compile-time i18n
- **Well-scoped:** Minimal change, clear semantics

### Use Cases

- **LiveSvelteGettext:** Extract translations from Svelte components
- **Surface:** Extract translations from Surface templates
- **Custom macro systems:** Any library generating gettext calls

### Testing

Added comprehensive tests covering:
- Override location is used when provided
- Falls back to `caller.file` and `caller.line` when not provided
- Works with both singular and plural messages

---

## Timeline

**Phase 1: Discussion** (2-3 weeks)
- Open GitHub issue describing the problem and proposed solution
- Gather feedback from maintainers and community
- Refine API based on feedback

**Phase 2: Implementation** (1 week)
- Fork Gettext repository
- Implement changes as described above
- Write comprehensive tests
- Update documentation

**Phase 3: PR Review** (2-4 weeks)
- Submit PR with detailed description
- Address reviewer feedback
- Iterate on implementation

**Phase 4: Release** (Variable)
- Wait for PR to be merged
- Wait for next Gettext release
- Update LiveSvelteGettext to use native support

**Total estimated time:** 6-10 weeks from start to release

## Acceptance Criteria

- [ ] GitHub issue opened on Gettext repository
- [ ] Community feedback gathered and incorporated
- [ ] Fork created with implementation
- [ ] Tests written and passing
- [ ] Documentation updated
- [ ] PR submitted to upstream Gettext
- [ ] PR merged (subject to maintainer approval)
- [ ] Feature released in Gettext version X.Y.Z
- [ ] LiveSvelteGettext updated to use native support when available

## Alternative: If PR Not Accepted

If the Gettext maintainers don't accept this change, we have several options:

1. **Keep CustomExtractor** - Our current workaround works perfectly fine
2. **Fork Gettext** - Maintain our own fork with this feature (not ideal)
3. **Advocate for alternative** - Work with maintainers to find different solution

The key insight: **We don't need this PR to ship LiveSvelteGettext.** Our `CustomExtractor` workaround is solid and reliable. This PR is about moving the community forward and making the solution cleaner.

## References

- **Gettext Repository:** https://github.com/elixir-gettext/gettext
- **T006 Task:** Related task describing the original problem
- **LiveSvelteGettext.CustomExtractor:** Our current workaround implementation

## Questions for Maintainers

When opening the issue, ask:

1. Is this a use case you'd like to support officially?
2. Would you prefer a different API design? (e.g., custom field in Macro.Env?)
3. Are there concerns about performance or security we should address?
4. Would you like to see a prototype implementation first?

## Success Metrics

- ✅ PR accepted and merged
- ✅ Feature available in released Gettext version
- ✅ Other libraries adopt the pattern
- ✅ Documented as official way to handle macro-generated translations

## Related

- **Part of:** Overall LiveSvelteGettext project
- **Blocks:** Nothing (we have a working solution)
- **Depends on:** Gettext maintainer availability and interest

---

**Note:** This is a **nice-to-have** improvement, not a blocker. We can ship LiveSvelteGettext v1.0 with the CustomExtractor workaround and upgrade later if/when this PR is accepted.
