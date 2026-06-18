defmodule WPL.Enforce.MatcherVocabCodegenTest do
  use ExUnit.Case, async: true

  alias WPL.Enforce.MatcherVocab

  @root File.cwd!()

  test "committed matcher_vocab.ex equals a fresh codegen run" do
    path = Path.join(@root, "lib/wpl/enforce/matcher_vocab.ex")
    before = File.read!(path)

    {_, 0} =
      System.cmd("mix", ["run", "scripts/gen_matcher_vocab.exs"],
        cd: @root,
        stderr_to_stdout: true
      )

    assert File.read!(path) == before
  end

  test "exposes the 16 qualifier tokens and the short-plural override" do
    json = Path.join(@root, "priv/data/matcher-vocab.json") |> File.read!() |> Jason.decode!()
    assert MatcherVocab.qualifier_tokens() == json["qualifier_tokens"]
    assert length(MatcherVocab.qualifier_tokens()) == 16
    assert MatcherVocab.short_plurals() == %{"ups" => "up"}
  end
end
