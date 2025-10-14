defmodule Mix.Tasks.LiveSvelteGettext.Install do
  @moduledoc """
  Installs LiveSvelteGettext in your Phoenix application.

  ## Usage

      $ mix igniter.install live_svelte_gettext

  This installer will:
  1. Detect your Gettext backend automatically
  2. Detect your Svelte directory (or prompt if multiple found)
  3. Create a SvelteStrings module with the correct configuration
  4. Copy the TypeScript translation library to your assets directory
  5. Provide usage instructions

  ## Options

    * `--gettext-backend` - Manually specify the Gettext backend module (e.g., MyAppWeb.Gettext)
    * `--svelte-path` - Manually specify the Svelte directory path (e.g., assets/svelte)
    * `--module-name` - Specify the name for the SvelteStrings module (default: detected from Gettext backend)

  ## Examples

      # Automatic detection
      $ mix igniter.install live_svelte_gettext

      # Manual configuration
      $ mix igniter.install live_svelte_gettext --gettext-backend MyAppWeb.Gettext --svelte-path assets/svelte
  """

  use Igniter.Mix.Task

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
    |> copy_typescript_library()
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
    case File.ls("lib") do
      {:ok, _} ->
        # Find all .ex files
        Path.wildcard("lib/**/*.ex")
        |> Enum.filter(fn file ->
          case File.read(file) do
            {:ok, content} ->
              # Look for "use Gettext.Backend" or "use Gettext, "
              String.contains?(content, "use Gettext.Backend") ||
                String.contains?(content, "use Gettext,")

            _ ->
              false
          end
        end)
        |> Enum.map(&extract_module_name/1)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
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
    # Convert MyAppWeb.Gettext -> MyAppWeb.SvelteStrings
    backend
    |> Module.split()
    |> List.replace_at(-1, "SvelteStrings")
    |> Module.concat()
  end

  ## Application Configuration

  defp add_application_config(igniter) do
    backend = Igniter.assign(igniter, :lsg_backend)

    if is_nil(backend) do
      igniter
    else
      # Add configuration to config/config.exs
      Igniter.Project.Config.configure(
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
    backend = Igniter.assign(igniter, :lsg_backend)
    svelte_path = Igniter.assign(igniter, :lsg_svelte_path)
    module_name = Igniter.assign(igniter, :lsg_module_name)

    if is_nil(backend) || is_nil(svelte_path) || is_nil(module_name) do
      igniter
    else
      # Generate module content
      module_code = """
      defmodule #{inspect(module_name)} do
        @moduledoc \"\"\"
        Translation strings extracted from Svelte components.

        This module is automatically managed by LiveSvelteGettext.
        \"\"\"

        use Gettext.Backend, otp_app: #{inspect(backend.__gettext__(:otp_app))}
        use LiveSvelteGettext,
          gettext_backend: #{inspect(backend)},
          svelte_path: "#{svelte_path}"
      end
      """

      Igniter.Project.Module.create_module(
        igniter,
        module_name,
        module_code,
        :source_folder
      )
    end
  end

  ## File Operations

  defp copy_typescript_library(igniter) do
    # Source: TypeScript library in our priv directory (or assets/js)
    # We need to determine where our library code lives
    source_path = find_typescript_library_source()

    # Destination: User's assets/js directory
    dest_path = "assets/js/translations.ts"

    case source_path do
      nil ->
        Igniter.add_warning(
          igniter,
          """
          Could not find TypeScript translation library to copy.

          Please manually copy the library from:
          https://github.com/xnilsson/live_svelte_gettext/blob/main/assets/js/translations.ts

          To: #{dest_path}
          """
        )

        igniter

      source ->
        # Check if destination already exists
        if File.exists?(dest_path) do
          Igniter.add_notice(
            igniter,
            """
            File #{dest_path} already exists. Skipping copy.

            If you want to update it, please remove the existing file first.
            """
          )

          igniter
        else
          # Copy the file
          case File.read(source) do
            {:ok, content} ->
              Igniter.create_new_file(igniter, dest_path, content)

            {:error, reason} ->
              Igniter.add_warning(
                igniter,
                "Failed to read TypeScript library: #{inspect(reason)}"
              )

              igniter
          end
        end
    end
  end

  defp find_typescript_library_source do
    # Try to find the TypeScript library in the package
    possible_paths = [
      # When installed as a dependency
      Path.join([:code.priv_dir(:live_svelte_gettext), "static", "translations.ts"]),
      # When developing locally
      Path.join([File.cwd!(), "assets", "js", "translations.ts"])
    ]

    Enum.find(possible_paths, &File.exists?/1)
  end

  ## User Instructions

  defp add_usage_notice(igniter) do
    backend = Igniter.assign(igniter, :lsg_backend)
    svelte_path = Igniter.assign(igniter, :lsg_svelte_path)
    module_name = Igniter.assign(igniter, :lsg_module_name)

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

      1. Import the component in your view helpers:

          # In lib/my_app_web.ex
          def html do
            quote do
              # ... existing code ...
              import LiveSvelteGettext.Components
            end
          end

      2. Add the translation injection component to your layout or LiveView template:

          # In your layout or LiveView template (before Svelte components)
          <.svelte_translations />

          <.svelte name="MyComponent" props={%{...}} />

      3. In your Svelte components, use the translation functions:

          <script>
            import { gettext, ngettext } from './translations'

            // Translations are automatically available from the script tag
          </script>

          <p>{gettext("Hello, world!")}</p>

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
