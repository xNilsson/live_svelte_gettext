defmodule LiveSvelteGettext.Compiler do
  @moduledoc """
  Compile-time code generation for LiveSvelteGettext.

  This module is responsible for:
  1. Validating configuration options
  2. Scanning Svelte files and extracting translation strings
  3. Generating AST for gettext/ngettext calls (for extraction)
  4. Generating the runtime `all_translations/1` function
  5. Setting up `@external_resource` for automatic recompilation
  """

  @doc """
  Validates the options passed to `use LiveSvelteGettext`.

  Raises a `ArgumentError` if options are invalid.

  ## Examples

      iex> LiveSvelteGettext.Compiler.validate_options!(
      ...>   gettext_backend: MyApp.Gettext,
      ...>   svelte_path: "assets/svelte"
      ...> )
      :ok

      iex> LiveSvelteGettext.Compiler.validate_options!([])
      ** (ArgumentError) :gettext_backend is required
  """
  @spec validate_options!(keyword()) :: :ok
  def validate_options!(opts) do
    unless Keyword.has_key?(opts, :gettext_backend) do
      raise ArgumentError, ":gettext_backend is required"
    end

    unless Keyword.has_key?(opts, :svelte_path) do
      raise ArgumentError, ":svelte_path is required"
    end

    backend = Keyword.get(opts, :gettext_backend)

    # Accept atoms or AST expressions (at compile time, module names can be complex AST)
    # Valid forms: MyModule, __MODULE__, Some.Nested.Module (which is an alias AST)
    # Also accept {:__block__, _, [atom]} which is how quoted module names work
    valid_backend =
      is_atom(backend) or
        (is_tuple(backend) and elem(backend, 0) in [:__MODULE__, :__aliases__]) or
        (is_tuple(backend) and match?({:__block__, _, [atom]} when is_atom(atom), backend))

    unless valid_backend do
      raise ArgumentError, ":gettext_backend must be a module name"
    end

    path = Keyword.get(opts, :svelte_path)

    unless is_binary(path) do
      raise ArgumentError, ":svelte_path must be a string"
    end

    :ok
  end

  @doc """
  Generates the complete AST for the using module.

  This is called at compile time and returns quoted expressions that will
  be injected into the caller's module.

  ## What gets generated:

  1. `use Gettext, backend: <backend>` for gettext integration
  2. `@external_resource` attributes for each Svelte file
  3. Module attribute with extracted translations for compile-time use
  4. Generated gettext/ngettext calls (for mix gettext.extract)
  5. `all_translations/1` function for runtime translation access
  6. `__lsg_metadata__/0` debug function

  ## Examples

      iex> ast = LiveSvelteGettext.Compiler.generate(
      ...>   MyApp.Gettext,
      ...>   MyApp.Gettext,
      ...>   "test/fixtures/svelte"
      ...> )
      iex> is_list(ast)
      true
  """
  @spec generate(module(), module(), String.t()) :: Macro.t()
  def generate(_caller_module, gettext_backend, svelte_path) do
    # Find all Svelte files
    svelte_files = find_svelte_files(svelte_path)

    # Extract translations from all files
    extractions = LiveSvelteGettext.Extractor.extract_all(svelte_files)

    # Generate the AST
    quote do
      # 1. Use Gettext with the specified backend
      use Gettext, backend: unquote(gettext_backend)

      # 2. Add @external_resource for each Svelte file (for recompilation)
      unquote_splicing(generate_external_resources(svelte_files))

      # 3. Store extractions as a module attribute for compile-time use
      @lsg_extractions unquote(Macro.escape(extractions))
      @lsg_svelte_files unquote(svelte_files)
      @lsg_gettext_backend unquote(gettext_backend)

      # 4. Generate gettext/ngettext calls (for mix gettext.extract to discover)
      unquote_splicing(generate_extraction_calls(extractions))

      # 5. Generate the runtime all_translations/1 function
      unquote(generate_all_translations_function(extractions, gettext_backend))

      # 6. Generate the debug metadata function
      unquote(generate_metadata_function())
    end
  end

  ## Private functions

  @doc false
  def find_svelte_files(svelte_path) do
    # Make path absolute if it's relative
    full_path =
      if Path.type(svelte_path) == :absolute do
        svelte_path
      else
        Path.join(File.cwd!(), svelte_path)
      end

    # Recursively find all .svelte files
    case File.ls(full_path) do
      {:ok, _entries} ->
        Path.join(full_path, "**/*.svelte")
        |> Path.wildcard()
        |> Enum.sort()

      {:error, _reason} ->
        # Directory doesn't exist - return empty list
        # This allows the module to compile even if the directory doesn't exist yet
        []
    end
  end

  # Generate @external_resource attributes for automatic recompilation
  defp generate_external_resources(files) do
    Enum.map(files, fn file ->
      quote do
        @external_resource unquote(file)
      end
    end)
  end

  # Generate extraction calls that mix gettext.extract can discover
  # Uses CustomExtractor to preserve accurate source locations in .pot files
  defp generate_extraction_calls(extractions) do
    [
      quote do
        # Only perform extraction when mix gettext.extract is running
        if Gettext.Extractor.extracting?() do
          # Generate one extraction call per reference to preserve all file:line locations
          (unquote_splicing(
             Enum.flat_map(extractions, fn extraction ->
               Enum.flat_map(extraction.references, fn {file, line} ->
                 case extraction.type do
                   :gettext ->
                     [
                       quote do
                         LiveSvelteGettext.CustomExtractor.extract_with_location(
                           __ENV__,
                           @lsg_gettext_backend,
                           :default,
                           nil,
                           unquote(extraction.msgid),
                           [],
                           unquote(file),
                           unquote(line)
                         )
                       end
                     ]

                   :ngettext ->
                     [
                       quote do
                         LiveSvelteGettext.CustomExtractor.extract_plural_with_location(
                           __ENV__,
                           @lsg_gettext_backend,
                           :default,
                           nil,
                           {unquote(extraction.msgid), unquote(extraction.plural)},
                           [],
                           unquote(file),
                           unquote(line)
                         )
                       end
                     ]
                 end
               end)
             end)
           ))
        end
      end
    ]
  end

  # Generate the all_translations/1 function
  defp generate_all_translations_function(extractions, gettext_backend) do
    quote do
      @doc """
      Returns all translations for the given locale.

      This function is generated at compile time and includes all translation
      strings found in your Svelte components.

      ## Parameters

      - `locale` - The locale string (e.g., "en", "es", "fr")

      ## Returns

      A map with translation keys as strings and translated values:

          %{
            "Hello" => "Hello",
            "Welcome back, %{name}!" => "Welcome back, %{name}!",
            ...
          }

      ## Examples

          iex> #{inspect(__MODULE__)}.all_translations("en")
          %{"Save" => "Save", "Delete" => "Delete"}
      """
      @spec all_translations(String.t()) :: %{String.t() => String.t()}
      def all_translations(locale) when is_binary(locale) do
        # Build the translation map at runtime
        backend = unquote(gettext_backend)
        extractions = unquote(Macro.escape(extractions))

        Enum.reduce(extractions, %{}, fn extraction, acc ->
          add_translation_to_map(acc, extraction, backend, locale)
        end)
      end

      defp add_translation_to_map(acc, %{type: :gettext, msgid: msgid}, backend, locale) do
        # For simple gettext, retrieve the translation WITHOUT interpolation
        # We pass an empty bindings map, which will cause Gettext to return
        # {:missing_bindings, translated_string, missing_keys} if there are interpolation
        # markers in the msgstr. This gives us the raw msgstr with %{key} patterns intact.
        translated = extract_gettext_translation(backend, locale, msgid)
        Map.put(acc, msgid, translated)
      end

      defp add_translation_to_map(
             acc,
             %{type: :ngettext, msgid: msgid, plural: plural},
             _backend,
             _locale
           ) do
        # For ngettext, we need to get raw translations without interpolation.
        # Problem: lngettext automatically adds :count to bindings, causing interpolation.
        #
        # Solution: Since we don't have a way to bypass interpolation for plural forms,
        # we'll return the raw msgid and msgid_plural from the extraction.
        # The frontend will handle interpolation at runtime with actual values.
        #
        # Note: This means for non-default locales, users will need to manually
        # provide translations. A future enhancement could parse .po files directly.
        key = "#{msgid}|||#{plural}"
        Map.put(acc, key, %{"one" => msgid, "other" => plural})
      end

      defp extract_gettext_translation(backend, locale, msgid) do
        case backend.lgettext(locale, "default", nil, msgid, %{}) do
          {:ok, str} -> str
          {:default, str} -> str
          {:missing_bindings, str, _keys} -> str
        end
      end
    end
  end

  # Generate the debug metadata function
  defp generate_metadata_function do
    quote do
      @doc """
      Returns metadata about the extracted translations.

      This is useful for debugging and understanding what translations
      were found at compile time.

      ## Returns

      A map containing:
      - `:extractions` - List of all extracted translation strings
      - `:svelte_files` - List of Svelte files that were scanned
      - `:gettext_backend` - The Gettext backend being used

      ## Examples

          iex> #{inspect(__MODULE__)}.__lsg_metadata__()
          %{
            extractions: [...],
            svelte_files: ["assets/svelte/Button.svelte", ...],
            gettext_backend: MyApp.Gettext
          }
      """
      @spec __lsg_metadata__() :: %{
              extractions: [LiveSvelteGettext.Extractor.extraction()],
              svelte_files: [String.t()],
              gettext_backend: module()
            }
      def __lsg_metadata__ do
        %{
          extractions: @lsg_extractions,
          svelte_files: @lsg_svelte_files,
          gettext_backend: @lsg_gettext_backend
        }
      end
    end
  end
end
