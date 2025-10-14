defmodule Mix.Tasks.LiveSvelteGettext.Setup do
  @moduledoc """
  Quick reference task for LiveSvelteGettext setup.

  ## Usage

      $ mix live_svelte_gettext.setup

  This task provides a quick reminder of the installation steps.

  ## Setup is Simple!

  1. Install the NPM package:
     ```bash
     npm install live-svelte-gettext
     ```

  2. Add `<.svelte_translations />` to your template

  3. Use translations in your Svelte components:
     ```javascript
     import { gettext } from 'live-svelte-gettext'
     gettext("Hello, world!")
     ```

  That's it! No hook registration or manual initialization needed.
  Translations automatically initialize on first use.
  """

  use Mix.Task

  @shortdoc "Interactive setup for LiveSvelteGettext JavaScript integration"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("""

    #{IO.ANSI.cyan()}╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║         LiveSvelteGettext Setup Guide                     ║
    ║                                                           ║
    ╚═══════════════════════════════════════════════════════════╝#{IO.ANSI.reset()}

    #{IO.ANSI.green()}✓ Good news! Setup is simple - just 3 steps:#{IO.ANSI.reset()}

    #{IO.ANSI.yellow()}1. Install the NPM package:#{IO.ANSI.reset()}

       #{IO.ANSI.cyan()}npm install live-svelte-gettext#{IO.ANSI.reset()}

    #{IO.ANSI.yellow()}2. Add translations to your template:#{IO.ANSI.reset()}

       #{IO.ANSI.cyan()}<.svelte_translations />#{IO.ANSI.reset()}

    #{IO.ANSI.yellow()}3. Use translations in your Svelte components:#{IO.ANSI.reset()}

       #{IO.ANSI.cyan()}<script>
         import { gettext, ngettext } from 'live-svelte-gettext'
       </script>

       <p>{gettext("Hello, world!")}</p>
       <p>{ngettext("1 item", "%{count} items", itemCount)}</p>#{IO.ANSI.reset()}

    #{IO.ANSI.green()}That's it! No hook registration needed.#{IO.ANSI.reset()}
    Translations automatically initialize on first use.

    #{IO.ANSI.yellow()}Extract and merge translations:#{IO.ANSI.reset()}

       #{IO.ANSI.cyan()}mix gettext.extract && mix gettext.merge priv/gettext#{IO.ANSI.reset()}

    #{IO.ANSI.cyan()}For more information, visit:
    https://github.com/xnilsson/live_svelte_gettext#{IO.ANSI.reset()}

    """)
  end
end
