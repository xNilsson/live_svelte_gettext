defmodule Mix.Tasks.LiveSvelteGettext.Install do
  @moduledoc """
  Installs LiveSvelteGettext in your Phoenix application.

  ## Usage

      $ mix igniter.install live_svelte_gettext

  This installer will:
  1. Detect your Gettext backend automatically
  2. Detect your Svelte directory (or prompt if multiple found)
  3. Create a SvelteStrings module with the correct configuration
  4. Add `use LiveSvelteGettext` to your Gettext backend
  5. Add `import LiveSvelteGettext.Components` to your web module
  6. Add application configuration to config/config.exs
  7. Provide next steps for completing the installation

  ## Options

    * `--gettext-backend` - Manually specify the Gettext backend module (e.g., MyAppWeb.Gettext)
    * `--svelte-path` - Manually specify the Svelte directory path (e.g., assets/svelte)
    * `--module-name` - Specify the name for the SvelteStrings module (default: detected from Gettext backend)

  ## Examples

      # Automatic detection
      $ mix igniter.install live_svelte_gettext

      # Manual configuration
      $ mix igniter.install live_svelte_gettext --gettext-backend MyAppWeb.Gettext --svelte-path assets/svelte

  ## After Installation

  You can optionally install the npm package or use the bundled files:

  ```bash
  # Option A: Install from npm (recommended)
  npm install live-svelte-gettext

  # Option B: Use bundled files (no installation needed)
  # Available at deps/live_svelte_gettext/assets/dist/
  ```
  """

  use Igniter.Mix.Task

  alias Igniter.Project.Config

  @impl Igniter.Mix.Task
  def info(_argv, _parent) do
    %Igniter.Mix.Task.Info{
      group: :igniter,
      example: "mix igniter.install live_svelte_gettext",
      schema: [
        gettext_backend: :string,
        svelte_path: :string,
        module_name: :string
      ],
      installs: []
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    options = igniter.args.options

    igniter
    |> detect_or_prompt_configuration(options)
    |> add_application_config()
    |> create_svelte_strings_module()
    |> add_use_to_gettext_backend()
    |> add_component_import_to_web_module()
    |> add_usage_notice()
  end

  ## Detection and Configuration

  defp detect_or_prompt_configuration(igniter, options) do
    # Get or detect Gettext backend
    backend =
      case options[:gettext_backend] do
        nil -> detect_gettext_backend(igniter)
        backend_str -> String.to_atom("Elixir.#{backend_str}")
      end

    # Get or detect Svelte path
    svelte_path =
      case options[:svelte_path] do
        nil -> detect_svelte_path(igniter)
        path -> path
      end

    # Determine module name
    module_name =
      case options[:module_name] do
        nil -> derive_module_name(backend)
        name -> String.to_atom("Elixir.#{name}")
      end

    # Store configuration in igniter assigns for later steps
    igniter
    |> Igniter.assign(:lsg_backend, backend)
    |> Igniter.assign(:lsg_svelte_path, svelte_path)
    |> Igniter.assign(:lsg_module_name, module_name)
  end

  defp detect_gettext_backend(igniter) do
    # Search for modules that use Gettext.Backend
    case find_gettext_backends(igniter) do
      [] ->
        Igniter.add_warning(
          igniter,
          """
          Could not detect a Gettext backend in your project.

          Please ensure you have a module like:

              defmodule MyAppWeb.Gettext do
                use Gettext.Backend, otp_app: :my_app
              end

          Then run the installer with --gettext-backend option:

              mix igniter.install live_svelte_gettext --gettext-backend MyAppWeb.Gettext
          """
        )

        nil

      [backend] ->
        backend

      backends ->
        Igniter.add_warning(
          igniter,
          """
          Multiple Gettext backends found: #{inspect(backends)}

          Please specify which one to use with --gettext-backend option:

              mix igniter.install live_svelte_gettext --gettext-backend MyAppWeb.Gettext
          """
        )

        # Default to first one
        List.first(backends)
    end
  end

  defp find_gettext_backends(_igniter) do
    # Search for modules that define Gettext backends by looking for
    # "use Gettext.Backend" in .ex files
    #
    # IMPORTANT: We must ONLY match "use Gettext.Backend", NOT "use Gettext,"
    # because many Phoenix modules use Gettext as a consumer (e.g., web modules)
    # but are not themselves backends.
    case File.ls("lib") do
      {:ok, _} ->
        # Find all .ex files
        Path.wildcard("lib/**/*.ex")
        |> Enum.filter(&file_contains_gettext_backend?/1)
        |> Enum.map(&extract_module_name/1)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp file_contains_gettext_backend?(file) do
    case File.read(file) do
      {:ok, content} ->
        # Look ONLY for "use Gettext.Backend" - actual backend definition
        # Do NOT match "use Gettext," which is for consumers
        String.contains?(content, "use Gettext.Backend")

      _ ->
        false
    end
  end

  defp extract_module_name(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        # Extract module name from "defmodule ModuleName do"
        case Regex.run(~r/defmodule\s+([\w.]+)\s+do/, content) do
          [_, module_name] -> String.to_atom("Elixir.#{module_name}")
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp detect_svelte_path(igniter) do
    # Common Svelte directory locations in Phoenix projects
    common_paths = [
      "assets/svelte",
      "assets/js/svelte",
      "priv/svelte",
      "lib/my_app_web/svelte"
    ]

    # Check which paths exist
    existing_paths =
      common_paths
      |> Enum.filter(fn path ->
        File.dir?(Path.join(File.cwd!(), path))
      end)

    case existing_paths do
      [] ->
        Igniter.add_warning(
          igniter,
          """
          Could not detect a Svelte directory in your project.

          Common locations checked:
          #{Enum.map_join(common_paths, "\n", &"  - #{&1}")}

          Please specify the path with --svelte-path option:

              mix igniter.install live_svelte_gettext --svelte-path assets/svelte

          Or create a Svelte directory first.
          """
        )

        "assets/svelte"

      [path] ->
        path

      paths ->
        Igniter.add_notice(
          igniter,
          """
          Multiple Svelte directories found: #{inspect(paths)}

          Using the first one: #{List.first(paths)}

          To use a different one, specify with --svelte-path option.
          """
        )

        List.first(paths)
    end
  end

  defp derive_module_name(nil), do: nil

  defp derive_module_name(backend) when is_atom(backend) do
    # Convert MyAppWeb.Gettext -> MyAppWeb.Gettext.SvelteStrings
    # This should be a submodule of the Gettext backend
    Module.concat(backend, SvelteStrings)
  end

  defp extract_otp_app(backend) when is_atom(backend) do
    # Try to find the backend's source file and extract otp_app
    backend_path =
      backend
      |> Module.split()
      |> Enum.map(&Macro.underscore/1)
      |> Path.join()

    # Check common locations
    possible_paths = [
      "lib/#{backend_path}.ex",
      "lib/#{backend_path}/gettext.ex"
    ]

    otp_app = Enum.find_value(possible_paths, &extract_otp_app_from_file/1)

    # Fallback: derive from module name (MyAppWeb.Gettext -> :my_app)
    otp_app || derive_otp_app_from_module(backend)
  end

  defp extract_otp_app_from_file(path) do
    with {:ok, content} <- File.read(path),
         [_, app] <- Regex.run(~r/use\s+Gettext\.Backend,\s+otp_app:\s+:(\w+)/, content) do
      String.to_atom(app)
    else
      _ -> nil
    end
  end

  defp derive_otp_app_from_module(backend) do
    # MyAppWeb.Gettext -> :my_app
    backend
    |> Module.split()
    |> List.first()
    |> Macro.underscore()
    |> String.to_atom()
  end

  ## Application Configuration

  defp add_application_config(igniter) do
    backend = igniter.assigns[:lsg_backend]

    if is_nil(backend) do
      igniter
    else
      # Add configuration to config/config.exs
      Config.configure(
        igniter,
        "config.exs",
        :live_svelte_gettext,
        [:gettext],
        backend
      )
    end
  end

  ## Module Creation

  defp create_svelte_strings_module(igniter) do
    backend = igniter.assigns[:lsg_backend]
    svelte_path = igniter.assigns[:lsg_svelte_path]
    module_name = igniter.assigns[:lsg_module_name]

    if is_nil(backend) || is_nil(svelte_path) || is_nil(module_name) do
      igniter
    else
      # Extract otp_app from the backend module
      otp_app = extract_otp_app(backend)

      # Generate module content (just the body, not the defmodule wrapper)
      # Using string concatenation to avoid nested heredoc confusion with Credo
      moduledoc = ~s(@moduledoc \"\"\"
      Translation strings extracted from Svelte components.

      This module is automatically managed by LiveSvelteGettext.
      \"\"\")

      module_contents =
        moduledoc <>
          "\n\n" <>
          "use Gettext.Backend, otp_app: #{inspect(otp_app)}\n" <>
          "use LiveSvelteGettext,\n" <>
          "  gettext_backend: #{inspect(backend)},\n" <>
          "  svelte_path: \"#{svelte_path}\"\n"

      Igniter.Project.Module.create_module(
        igniter,
        module_name,
        module_contents
      )
    end
  end

  # Test helper functions (exposed for testing only)
  # These should be @doc false to indicate they're not part of the public API
  @doc false
  def derive_module_name_test(backend), do: derive_module_name(backend)

  @doc false
  def add_component_import_test(content), do: add_component_import(content)

  @doc false
  def find_gettext_backends_test(igniter), do: find_gettext_backends(igniter)

  ## Gettext Backend Integration

  defp add_use_to_gettext_backend(igniter) do
    backend = igniter.assigns[:lsg_backend]
    svelte_path = igniter.assigns[:lsg_svelte_path]

    if is_nil(backend) || is_nil(svelte_path) do
      igniter
    else
      backend_path = derive_backend_path(backend)
      update_backend_file(igniter, backend, backend_path, svelte_path)
    end
  end

  defp derive_backend_path(backend) do
    backend
    |> Module.split()
    |> Enum.map(&Macro.underscore/1)
    |> Path.join()
    |> then(&"lib/#{&1}.ex")
  end

  defp update_backend_file(igniter, backend, backend_path, svelte_path) do
    cond do
      not File.exists?(backend_path) ->
        Igniter.add_warning(
          igniter,
          "#{backend_path} not found. Please add 'use LiveSvelteGettext' to your Gettext backend manually."
        )

      match?({:ok, content} when is_binary(content), File.read(backend_path)) and
          String.contains?(elem(File.read(backend_path), 1), "use LiveSvelteGettext") ->
        Igniter.add_notice(igniter, "LiveSvelteGettext already configured in #{backend}")

      match?({:ok, content} when is_binary(content), File.read(backend_path)) ->
        {:ok, content} = File.read(backend_path)
        updated_content = add_use_live_svelte_gettext(content, backend, svelte_path)
        File.write!(backend_path, updated_content)
        Igniter.add_notice(igniter, "Added 'use LiveSvelteGettext' to #{backend}")

      true ->
        Igniter.add_warning(igniter, "Could not read #{backend_path}")
    end
  end

  defp add_use_live_svelte_gettext(content, backend, svelte_path) do
    # Find the line with "use Gettext.Backend" and add our use statement after it
    use_statement = """
      use LiveSvelteGettext,
        gettext_backend: #{inspect(backend)},
        svelte_path: "#{svelte_path}"
    """

    String.replace(
      content,
      ~r/(use\s+Gettext\.Backend,.*\n)/,
      "\\1#{use_statement}\n"
    )
  end

  ## Elixir Web Module Integration

  defp add_component_import_to_web_module(igniter) do
    backend = igniter.assigns[:lsg_backend]

    if is_nil(backend) do
      igniter
    else
      # Derive web module name (MonsterConstructionWeb.Gettext -> MonsterConstructionWeb)
      web_module =
        backend
        |> Module.split()
        |> List.first()
        |> then(&Module.concat([&1]))

      web_module_path = derive_web_module_path(web_module)
      update_web_module_file(igniter, web_module, web_module_path)
    end
  end

  defp derive_web_module_path(web_module) do
    web_module
    |> Module.split()
    |> Enum.map(&Macro.underscore/1)
    |> Path.join()
    |> then(&"lib/#{&1}.ex")
  end

  defp update_web_module_file(igniter, web_module, web_module_path) do
    cond do
      not File.exists?(web_module_path) ->
        Igniter.add_warning(
          igniter,
          "#{web_module_path} not found. Please add 'import LiveSvelteGettext.Components' to your html/0 function manually."
        )

      match?({:ok, content} when is_binary(content), File.read(web_module_path)) and
          String.contains?(elem(File.read(web_module_path), 1), "LiveSvelteGettext.Components") ->
        Igniter.add_notice(
          igniter,
          "LiveSvelteGettext.Components already imported in #{web_module}"
        )

      match?({:ok, content} when is_binary(content), File.read(web_module_path)) ->
        {:ok, content} = File.read(web_module_path)
        updated_content = add_component_import(content)
        File.write!(web_module_path, updated_content)

        Igniter.add_notice(
          igniter,
          "Added LiveSvelteGettext.Components import to #{web_module}"
        )

      true ->
        Igniter.add_warning(igniter, "Could not read #{web_module_path}")
    end
  end

  defp add_component_import(content) do
    # Check if already imported (idempotent)
    if String.contains?(content, "LiveSvelteGettext.Components") do
      content
    else
      # Add import to both html and live_view functions
      content
      |> add_import_to_html()
      |> add_import_to_live_view()
    end
  end

  defp add_import_to_html(content) do
    # Find the html function's quote block and add the import
    String.replace(
      content,
      ~r/(def\s+html\s+do\s+quote\s+do[^\n]*\n)/,
      "\\1      import LiveSvelteGettext.Components\n"
    )
  end

  defp add_import_to_live_view(content) do
    # Find the live_view function's quote block and add the import
    # live_view usually has: def live_view do\n    quote do\n
    String.replace(
      content,
      ~r/(def\s+live_view\s+do\s+quote\s+do[^\n]*\n)/,
      "\\1      import LiveSvelteGettext.Components\n"
    )
  end

  ## User Instructions

  defp add_usage_notice(igniter) do
    backend = igniter.assigns[:lsg_backend]
    svelte_path = igniter.assigns[:lsg_svelte_path]
    module_name = igniter.assigns[:lsg_module_name]

    Igniter.add_notice(
      igniter,
      """

      ✓ LiveSvelteGettext installed successfully!

      Configuration:
        Gettext Backend: #{inspect(backend)}
        Svelte Path: #{svelte_path}
        Module: #{inspect(module_name)}

      Application config added to config/config.exs:
        config :live_svelte_gettext, gettext: #{inspect(backend)}

      Next steps:

      1. (Optional) Install the npm package or use bundled files:

          $ npm install live-svelte-gettext

          Or use the bundled files at deps/live_svelte_gettext/assets/dist/

      2. Add the translation component to your layout or LiveView templates:

          # In your layout or LiveView template (before Svelte components)
          <.svelte_translations />

          <.svelte name="MyComponent" props={%{...}} />

      3. Use translations in your Svelte components:

          <script>
            import { gettext, ngettext } from 'live-svelte-gettext'
          </script>

          <p>{gettext("Hello, world!")}</p>
          <p>{ngettext("1 item", "%{count} items", 5)}</p>

          That's it! Translations automatically initialize on first use.

      4. Extract and merge translations:

          $ mix gettext.extract
          $ mix gettext.merge priv/gettext

      For more information, visit:
      https://github.com/xnilsson/live_svelte_gettext
      """
    )

    igniter
  end
end
