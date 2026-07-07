defmodule WPL.Data.DietaryTags do
  @moduledoc """
  GENERATED — do not edit. Run `mix run scripts/gen_dietary_tags.exs`.
  Source of truth: wpl/data/dietary-tags.json (vendored at priv/data/dietary-tags.json).
  Vocab version: 1.0.0
  """

  @ids [
    "vegetarian",
    "vegan",
    "gluten_free",
    "dairy_free"
  ]

  @doc "All recognised dietary-tag ids (list, in canonical order)."
  def ids, do: @ids
end
