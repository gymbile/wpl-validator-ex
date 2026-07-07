# GENERATOR for lib/wpl/data/goal_categories.ex — reads the vendored goal
# categories and (re)writes the generated Elixir module. Deterministic:
# preserves JSON array order. Run: mix run scripts/gen_goal_categories.exs

root = File.cwd!()
data = Path.join(root, "priv/data/goal-categories.json") |> File.read!() |> Jason.decode!()

version = data["version"]

ids =
  data["categories"]
  |> Enum.map(fn c -> "    #{inspect(c["id"])}" end)
  |> Enum.join(",\n")

module = """
defmodule WPL.Data.GoalCategories do
  @moduledoc \"\"\"
  GENERATED — do not edit. Run `mix run scripts/gen_goal_categories.exs`.
  Source of truth: wpl/data/goal-categories.json (vendored at priv/data/goal-categories.json).
  Vocab version: #{version}
  \"\"\"

  @ids [
#{ids}
  ]

  @doc "All recognised goal-category ids (list, in canonical order)."
  def ids, do: @ids
end
"""

out_path = Path.join(root, "lib/wpl/data/goal_categories.ex")
File.mkdir_p!(Path.dirname(out_path))
File.write!(out_path, module)
IO.puts("wrote lib/wpl/data/goal_categories.ex (#{version})")
