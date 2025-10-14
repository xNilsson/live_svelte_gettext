defmodule LiveSvelteGettext.CustomExtractor do
  @moduledoc """
  Wrapper around `Gettext.Extractor` that supports custom source file references.

  This module provides a way to extract translation strings with custom file and line
  references, which is necessary for macro-generated code that wants to preserve the
  original source location instead of reporting the macro expansion site.

  ## Problem

  When a macro generates `gettext()` calls, Gettext's extractor uses `__CALLER__.file`
  and `__CALLER__.line` to determine source references. This means all generated calls
  appear to originate from the macro invocation line, losing visibility into the actual
  source locations.

  ## Solution

  This module creates a modified `Macro.Env` struct with custom file and line values
  before passing it to `Gettext.Extractor.extract/6`. This "tricks" Gettext into
  recording the correct source references in POT files.

  ## Example

      # Instead of all references pointing to svelte_strings.ex:39
      #: lib/my_app_web/svelte_strings.ex:39
      msgid "Save Profile"

      # We get accurate references to the original Svelte files
      #: assets/svelte/components/Profile.svelte:42
      msgid "Save Profile"

  ## Usage

  This module is used internally by `LiveSvelteGettext.Compiler` when generating
  extraction calls. You typically won't need to use it directly.

  ## Future

  If Gettext adds official support for location overrides (see T007), this module
  will be updated to use the native API when available, falling back to this
  approach for older Gettext versions.
  """

  @doc """
  Extracts a singular translation message with a custom source location.

  This function creates a modified `Macro.Env` with the specified `file` and `line`,
  then calls `Gettext.Extractor.extract/6` so the POT file reference points to the
  custom location instead of the actual call site.

  ## Parameters

    * `env` - The macro environment from the call site (usually `__ENV__`)
    * `backend` - The Gettext backend module (e.g., `MyApp.Gettext`)
    * `domain` - The translation domain (`:default` or a binary string)
    * `msgctxt` - Optional message context (or `nil`)
    * `msgid` - The message ID to extract
    * `extracted_comments` - List of extracted comments (usually `[]`)
    * `file` - The source file path to record (e.g., `"assets/svelte/Button.svelte"`)
    * `line` - The line number to record (e.g., `42`)

  ## Returns

  Returns `:ok` after extraction is complete.

  ## Example

      LiveSvelteGettext.CustomExtractor.extract_with_location(
        __ENV__,
        MyApp.Gettext,
        :default,
        nil,
        "Hello, world!",
        [],
        "assets/svelte/Greeting.svelte",
        12
      )

  """
  @spec extract_with_location(
          Macro.Env.t(),
          module(),
          binary() | :default,
          binary() | nil,
          binary(),
          [binary()],
          binary(),
          non_neg_integer()
        ) :: :ok
  def extract_with_location(env, backend, domain, msgctxt, msgid, extracted_comments, file, line) do
    # Create a modified environment with custom file and line
    modified_env = %{env | file: file, line: line}

    # Call Gettext's extractor with the modified env
    Gettext.Extractor.extract(
      modified_env,
      backend,
      domain,
      msgctxt,
      msgid,
      extracted_comments
    )
  end

  @doc """
  Extracts a plural translation message with a custom source location.

  Similar to `extract_with_location/8`, but for plural messages that have both
  `msgid` and `msgid_plural`.

  ## Parameters

    * `env` - The macro environment from the call site (usually `__ENV__`)
    * `backend` - The Gettext backend module (e.g., `MyApp.Gettext`)
    * `domain` - The translation domain (`:default` or a binary string)
    * `msgctxt` - Optional message context (or `nil`)
    * `msgid_msgid_plural` - A tuple of `{msgid, msgid_plural}` for the singular and plural forms
    * `extracted_comments` - List of extracted comments (usually `[]`)
    * `file` - The source file path to record
    * `line` - The line number to record

  ## Returns

  Returns `:ok` after extraction is complete.

  ## Example

      LiveSvelteGettext.CustomExtractor.extract_plural_with_location(
        __ENV__,
        MyApp.Gettext,
        :default,
        nil,
        {"One item", "%{count} items"},
        [],
        "assets/svelte/ItemList.svelte",
        24
      )

  """
  @spec extract_plural_with_location(
          Macro.Env.t(),
          module(),
          binary() | :default,
          binary() | nil,
          {binary(), binary()},
          [binary()],
          binary(),
          non_neg_integer()
        ) :: :ok
  def extract_plural_with_location(
        env,
        backend,
        domain,
        msgctxt,
        {msgid, msgid_plural},
        extracted_comments,
        file,
        line
      ) do
    # Create a modified environment with custom file and line
    modified_env = %{env | file: file, line: line}

    # Call Gettext's extractor with the modified env
    Gettext.Extractor.extract(
      modified_env,
      backend,
      domain,
      msgctxt,
      {msgid, msgid_plural},
      extracted_comments
    )
  end
end
