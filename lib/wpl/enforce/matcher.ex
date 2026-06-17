defmodule WPL.Enforce.Matcher do
  @moduledoc """
  Fuzzy exercise-name matcher for the Pass-3 enforcement engine.

  Ported from wpl-validator-ts/src/enforce/matcher.ts. Pure functions.
  Any change here is a change to the safety contract — add a conformance
  fixture with every behavioral change.
  """

  @doc "Normalize a free-text name into a lowercase, underscore-separated token."
  @spec normalize(String.t()) :: String.t()
  def normalize(s) do
    s
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s_-]/, " ")
    |> String.replace(~r/\b(the|a|an|with|of|to)\b/, " ")
    |> String.trim()
    |> String.split(~r/[\s_-]+/)
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&stem_plural/1)
    |> Enum.join("_")
  end

  # Short plurals (<=3 chars) that ARE genuine plurals and must still stem.
  # The <=3 length guard below normally protects short tokens; this map
  # overrides that guard so compound names like "push_ups" match "push_up".
  # "abs" is deliberately NOT here: it is a canonical muscle-group token.
  @short_plurals %{"ups" => "up"}

  # Muscle-group and anatomical tokens that look like plurals but are canonical
  # singular forms. Checked before the trailing-s rule so they are never stemmed.
  @no_stem_words MapSet.new(["biceps", "triceps", "forceps", "news"])

  @doc "Strip a trailing English plural 's' from a token."
  @spec stem_plural(String.t()) :: String.t()
  def stem_plural(token) do
    len = String.length(token)

    cond do
      len <= 3 ->
        Map.get(@short_plurals, token, token)

      MapSet.member?(@no_stem_words, token) ->
        token

      String.ends_with?(token, "ss") or String.ends_with?(token, "us") or
          String.ends_with?(token, "is") ->
        token

      String.ends_with?(token, "ies") ->
        String.slice(token, 0, len - 3) <> "y"

      String.ends_with?(token, "es") and len > 4 ->
        String.slice(token, 0, len - 2)

      String.ends_with?(token, "s") ->
        String.slice(token, 0, len - 1)

      true ->
        token
    end
  end

  @qualifier_tokens MapSet.new([
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
                    ])

  defp core_tokens(blacklisted) do
    tokens =
      blacklisted
      |> normalize()
      |> String.split("_")
      |> Enum.filter(&(&1 != ""))

    pivot = Enum.find_index(tokens, &MapSet.member?(@qualifier_tokens, &1))

    if pivot == nil do
      tokens
    else
      Enum.take(tokens, pivot)
    end
  end

  @doc """
  Returns true when `extracted` (an exercise name from the plan) collides with
  `blacklisted` (a forbid pattern from a personalization rule).
  """
  @spec collides(String.t(), String.t()) :: boolean()
  def collides(extracted, blacklisted) do
    a = normalize(extracted)
    if a == "", do: false, else: do_collides(a, blacklisted)
  end

  defp do_collides(a, blacklisted) do
    core = core_tokens(blacklisted)
    if core == [], do: false, else: check_collides(a, blacklisted, core)
  end

  defp check_collides(a, blacklisted, core) do
    b = normalize(blacklisted)

    if a == b do
      true
    else
      a_tokens = a |> String.split("_") |> Enum.filter(&(&1 != ""))
      a_set = MapSet.new(a_tokens)

      if String.ends_with?(blacklisted, "_anything") do
        Enum.any?(core, &MapSet.member?(a_set, &1))
      else
        Enum.all?(core, &MapSet.member?(a_set, &1))
      end
    end
  end
end
