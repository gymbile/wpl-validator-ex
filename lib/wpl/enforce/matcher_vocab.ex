defmodule WPL.Enforce.MatcherVocab do
  @moduledoc """
  GENERATED — do not edit. Run `mix run scripts/gen_matcher_vocab.exs`.
  Source of truth: wpl/data/matcher-vocab.json (vendored at priv/data/matcher-vocab.json).
  Vocab version: 1.0.0
  """

  @qualifier_tokens [
    "below",
    "above",
    "deep",
    "heavy",
    "light",
    "weighted",
    "loaded",
    "max",
    "maximal",
    "parallel",
    "bodyweight",
    "kg",
    "lbs",
    "rom",
    "anything",
    "any"
  ]

  @short_plurals %{
    "ups" => "up"
  }

  @doc "Qualifier tokens (list, in canonical order)."
  def qualifier_tokens, do: @qualifier_tokens

  @doc "Short-plural overrides map."
  def short_plurals, do: @short_plurals
end
