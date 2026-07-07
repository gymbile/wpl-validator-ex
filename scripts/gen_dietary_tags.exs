# GENERATOR for lib/wpl/data/dietary_tags.ex — reads the vendored dietary
# tags and (re)writes the generated Elixir module. Deterministic: preserves
# JSON array order. Run: mix run scripts/gen_dietary_tags.exs

root = File.cwd!()
data = Path.join(root, "priv/data/dietary-tags.json") |> File.read!() |> Jason.decode!()

version = data["version"]

ids =
  data["tags"]
  |> Enum.map(fn t -> "    #{inspect(t["id"])}" end)
  |> Enum.join(",\n")

module = """
defmodule WPL.Data.DietaryTags do
  @moduledoc \"\"\"
  GENERATED — do not edit. Run `mix run scripts/gen_dietary_tags.exs`.
  Source of truth: wpl/data/dietary-tags.json (vendored at priv/data/dietary-tags.json).
  Vocab version: #{version}
  \"\"\"

  @ids [
#{ids}
  ]

  @doc "All recognised dietary-tag ids (list, in canonical order)."
  def ids, do: @ids
end
"""

out_path = Path.join(root, "lib/wpl/data/dietary_tags.ex")
File.mkdir_p!(Path.dirname(out_path))
File.write!(out_path, module)
IO.puts("wrote lib/wpl/data/dietary_tags.ex (#{version})")
