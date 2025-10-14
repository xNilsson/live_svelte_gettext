# Task 008: Simplify Translation Injection

## Status
**Completed** - 2025-01-14

## Context

Currently, we manually inject Svelte translations in each LiveView that uses Svelte components. This requires repetitive code in every LiveView's `render/1` function.

## Current Implementation

### Pattern in Every LiveView

Each LiveView using Svelte components must:

1. **Import the SvelteStrings module**:
```elixir
alias MonsterConstructionWeb.Gettext.SvelteStrings
```

2. **Fetch and assign translations in render/1**:
```elixir
def render(assigns) do
  # Get all Svelte translations for current locale
  locale = Gettext.get_locale(MonsterConstructionWeb.Gettext)
  assigns = assign(assigns, :translations, SvelteStrings.all_translations(locale))

  ~H"""
  <!-- ... -->
  """
end
```

3. **Inject script tag in template**:
```heex
<!-- Translations for Svelte components (embedded in script tag) -->
<script id="svelte-translations" type="application/json">
  <%= raw Jason.encode!(@translations) %>
</script>
```

### Examples in Codebase

This pattern is repeated in:
- `MonsterConstructionWeb.PatternGuideSvelteLive` (lines 127-136)
- `MonsterConstructionWeb.PatternViewerSvelteLive` (lines 69-79)

## Problem

**Repetitive Boilerplate**: Every LiveView using Svelte components needs identical code for translation injection. This violates DRY principles and increases maintenance burden.

**Risk of Inconsistency**: Developers might forget to add translation injection when creating new Svelte-enabled LiveViews, leading to missing translations.

**Manual Process**: No automatic way to ensure translations are always available to Svelte components.

## Question

**Could this be automated using a Plug or similar mechanism?**

### Potential Approaches

#### Option 1: Phoenix.Component Function Component
Create a reusable component that wraps Svelte components with translation injection:

```elixir
defmodule MonsterConstructionWeb.SvelteComponents do
  use Phoenix.Component
  import LiveSvelte

  attr :name, :string, required: true
  attr :props, :map, default: %{}
  attr :class, :string, default: ""
  slot :inner_block

  def svelte_with_translations(assigns) do
    locale = Gettext.get_locale(MonsterConstructionWeb.Gettext)
    translations = MonsterConstructionWeb.Gettext.SvelteStrings.all_translations(locale)
    assigns = assign(assigns, :translations, translations)

    ~H"""
    <script id="svelte-translations" type="application/json">
      <%= raw Jason.encode!(@translations) %>
    </script>

    <.svelte name={@name} props={@props} class={@class}>
      {render_slot(@inner_block)}
    </.svelte>
    """
  end
end
```

**Usage**:
```heex
<.svelte_with_translations
  name="layouts/PatternViewer"
  props={%{...}}
  class="w-full h-full"
/>
```

**Pros**: Simple, explicit, easy to understand
**Cons**: Still requires calling the wrapper component

#### Option 2: Layout Component
Move translation injection into the `Layouts.pattern/1` component since all pattern pages need it:

```elixir
def pattern(assigns) do
  locale = Gettext.get_locale(MonsterConstructionWeb.Gettext)
  translations = SvelteStrings.all_translations(locale)
  assigns = assign(assigns, :translations, translations)

  ~H"""
  <main class="">
    <!-- Translations for Svelte components -->
    <script id="svelte-translations" type="application/json">
      <%= raw Jason.encode!(@translations) %>
    </script>

    {render_slot(@inner_block)}
  </main>

  <.flash_group flash={@flash} />
  """
end
```

**Pros**: Completely automatic for all pattern views
**Cons**:
- Assumes all uses of `Layouts.pattern` need Svelte translations
- Couples layout to Svelte translation system
- Less flexible for non-Svelte views

#### Option 3: on_mount Hook
Create a LiveView `on_mount` callback that injects translations:

```elixir
defmodule MonsterConstructionWeb.SvelteTranslations do
  import Phoenix.Component

  def on_mount(:inject_translations, _params, _session, socket) do
    locale = Gettext.get_locale(MonsterConstructionWeb.Gettext)
    translations = MonsterConstructionWeb.Gettext.SvelteStrings.all_translations(locale)
    {:cont, assign(socket, :svelte_translations, translations)}
  end
end
```

**In LiveView**:
```elixir
defmodule MonsterConstructionWeb.PatternViewerSvelteLive do
  use MonsterConstructionWeb, :live_view

  on_mount {MonsterConstructionWeb.SvelteTranslations, :inject_translations}

  # translations automatically available in @svelte_translations
end
```

**Pros**: Automatic, declarative, follows Phoenix patterns
**Cons**: Still need to render script tag in template

#### Option 4: LiveSvelte Integration
Modify LiveSvelte library (or create wrapper) to automatically inject translations:

```elixir
# In MonsterConstructionWeb
defmacro __using__(:live_view) do
  quote do
    use Phoenix.LiveView
    import LiveSvelte
    # Auto-inject svelte translations helper
    on_mount MonsterConstructionWeb.SvelteTranslations
  end
end
```

**Pros**: Completely transparent, works everywhere
**Cons**: Complex, couples core infrastructure to Svelte translations

## Considerations

### Performance
- How often are translations fetched? (Currently: once per render)
- Could translations be cached per locale?
- Is JSON encoding expensive for large translation maps?

### Flexibility
- What if some LiveViews don't need Svelte translations?
- What if different Svelte components need different translation subsets?

### Maintainability
- Which approach is easiest for new developers to understand?
- Which approach is easiest to debug when translations are missing?

## Decision: Hybrid Approach (Option 1 + Config)

**Chosen Solution**: Phoenix Component with Application Config

We implemented a `<.svelte_translations />` component that combines the best aspects:

- **Explicit and discoverable** - developers know exactly what's happening
- **Zero boilerplate** - uses application config for default Gettext module
- **Flexible** - can override module, locale, and script ID when needed
- **Library-friendly** - doesn't require complex setup or coupling

### Implementation Details

#### 1. Component (`lib/livesvelte_gettext/components.ex`)

```elixir
defmodule LiveSvelteGettext.Components do
  use Phoenix.Component
  import Phoenix.HTML, only: [raw: 1]

  attr :gettext_module, :atom, default: nil
  attr :locale, :string, default: nil
  attr :id, :string, default: "svelte-translations"

  def svelte_translations(assigns) do
    # Get module from assigns or application config
    gettext_module =
      assigns.gettext_module ||
      Application.get_env(:livesvelte_gettext, :gettext) ||
      raise_configuration_error()

    # Fetch translations and render script tag
    # ...
  end
end
```

#### 2. Application Config (auto-added by installer)

```elixir
# config/config.exs
config :livesvelte_gettext,
  gettext: MyAppWeb.Gettext
```

#### 3. Usage

**Minimal (uses config):**
```heex
<.svelte_translations />
```

**With overrides:**
```heex
<.svelte_translations locale="es" />
<.svelte_translations gettext_module={@tenant.gettext_module} />
```

### Why This Approach?

✅ **Eliminates boilerplate** - Just `<.svelte_translations />` in template
✅ **Standard Phoenix pattern** - Uses application config like Ecto, Phoenix
✅ **Flexible** - Supports multi-tenant apps with explicit module override
✅ **Good errors** - Clear messages if misconfigured
✅ **Debuggable** - Easy to see script tag in HTML, clear where translations come from

### Related Files

**Implementation:**
- `lib/livesvelte_gettext/components.ex` - Component module
- `lib/mix/tasks/livesvelte_gettext.install.ex` - Installer (adds config)
- `test/livesvelte_gettext/components_test.exs` - Component tests

**Documentation:**
- `README.md` - Updated with component usage
- `mix.exs` - Added Components to docs

## Success Criteria

- [x] Decision made on approach (Hybrid: Component + Config)
- [x] Implementation completed
- [x] All Svelte components receive translations with minimal code
- [x] No regression in translation functionality
- [x] Documentation updated with new pattern
- [x] Tests added for component behavior
- [x] Installer updated to configure app automatically

## Migration Guide

For existing users who want to migrate:

### Before (Manual)
```elixir
def render(assigns) do
  locale = Gettext.get_locale(MyAppWeb.Gettext)
  assigns = assign(assigns, :translations, SvelteStrings.all_translations(locale))

  ~H"""
  <script id="svelte-translations" type="application/json">
    <%= raw Jason.encode!(@translations) %>
  </script>
  <.svelte name="MyComponent" props={%{...}} />
  """
end
```

### After (Component)
```elixir
def render(assigns) do
  ~H"""
  <.svelte_translations />
  <.svelte name="MyComponent" props={%{...}} />
  """
end
```

**Setup:**
1. Add to `config/config.exs`: `config :livesvelte_gettext, gettext: MyAppWeb.Gettext`
2. Import in view helpers: `import LiveSvelteGettext.Components`
3. Replace manual injection with `<.svelte_translations />`
