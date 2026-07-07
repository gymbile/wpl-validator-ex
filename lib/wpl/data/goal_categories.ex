defmodule WPL.Data.GoalCategories do
  @moduledoc """
  GENERATED — do not edit. Run `mix run scripts/gen_goal_categories.exs`.
  Source of truth: wpl/data/goal-categories.json (vendored at priv/data/goal-categories.json).
  Vocab version: 1.1.0
  """

  @ids [
    "weight_loss",
    "muscle_gain",
    "endurance",
    "strength",
    "flexibility",
    "mental_wellness",
    "nutrition",
    "habit",
    "recovery",
    "general_fitness",
    "custom"
  ]

  @doc "All recognised goal-category ids (list, in canonical order)."
  def ids, do: @ids
end
