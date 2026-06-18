# GENERATOR for lib/wpl/enforce/matcher_vocab.ex — reads the vendored matcher
# vocab and (re)writes the generated Elixir module. Deterministic: preserves
# JSON token order. Run: mix run scripts/gen_matcher_vocab.exs

root = File.cwd!()
data = Path.join(root, "priv/data/matcher-vocab.json") |> File.read!() |> Jason.decode!()

version = data["version"]
tokens =
  data["qualifier_tokens"]
  |> Enum.map(fn t -> "    #{inspect(t)}" end)
  |> Enum.join(",\n")

plurals =
  data["short_plurals"]
  |> Enum.map(fn {k, v} -> "    #{inspect(k)} => #{inspect(v)}" end)
  |> Enum.join(",\n")

module = """
defmodule WPL.Enforce.MatcherVocab do
  @moduledoc \"\"\"
  GENERATED — do not edit. Run `mix run scripts/gen_matcher_vocab.exs`.
  Source of truth: wpl/data/matcher-vocab.json (vendored at priv/data/matcher-vocab.json).
  Vocab version: #{version}
  \"\"\"

  @qualifier_tokens [
#{tokens}
  ]

  @short_plurals %{
#{plurals}
  }

  @doc "Qualifier tokens (list, in canonical order)."
  def qualifier_tokens, do: @qualifier_tokens

  @doc "Short-plural overrides map."
  def short_plurals, do: @short_plurals
end
"""

out_path = Path.join(root, "lib/wpl/enforce/matcher_vocab.ex")
File.write!(out_path, module)
IO.puts("wrote lib/wpl/enforce/matcher_vocab.ex (#{version})")
