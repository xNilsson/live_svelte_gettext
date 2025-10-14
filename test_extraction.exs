# Simple test to see if extraction works

defmodule SimpleTest.Gettext do
  use Gettext.Backend, otp_app: :livesvelte_gettext
end

defmodule SimpleTest.Module do
  use LiveSvelteGettext,
    gettext_backend: SimpleTest.Gettext,
    svelte_path: "test/fixtures"
end

# Enable extraction
Gettext.Extractor.enable()
IO.puts("Extracting?: #{Gettext.Extractor.extracting?()}")

# Try to trigger extraction by checking if the module code contains CustomExtractor calls
metadata = SimpleTest.Module.__lsg_metadata__()
IO.puts("\nExtractions found: #{length(metadata.extractions)}")
IO.inspect(List.first(metadata.extractions), limit: :infinity)

# Get POT files
pot_files = Gettext.Extractor.pot_files(:livesvelte_gettext, [])
IO.puts("\nPOT files: #{length(pot_files)}")

Gettext.Extractor.disable()
