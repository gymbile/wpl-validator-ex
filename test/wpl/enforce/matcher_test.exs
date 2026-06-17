defmodule WPL.Enforce.MatcherTest do
  use ExUnit.Case, async: true

  alias WPL.Enforce.Matcher

  describe "normalize/1" do
    test "lowercases and underscores free-text names" do
      assert Matcher.normalize("Jump Squat") == "jump_squat"
    end

    test "strips stop articles" do
      assert Matcher.normalize("The Squat") == "squat"
    end

    test "strips punctuation" do
      assert Matcher.normalize("bench-press!") == "bench_press"
    end

    test "deduplicates repeated separators" do
      assert Matcher.normalize("push  up") == "push_up"
    end
  end

  describe "stem_plural/1" do
    test "stems trailing s (squats -> squat)" do
      assert Matcher.stem_plural("squats") == "squat"
    end

    test "preserves ss endings (press stays press)" do
      assert Matcher.stem_plural("press") == "press"
    end

    test "preserves biceps" do
      assert Matcher.stem_plural("biceps") == "biceps"
    end

    test "preserves abs (3-char, not in SHORT_PLURALS)" do
      assert Matcher.stem_plural("abs") == "abs"
    end

    test "stems ups via SHORT_PLURALS (compound plural fix)" do
      assert Matcher.stem_plural("ups") == "up"
    end

    test "normalize push_ups -> push_up via SHORT_PLURALS" do
      assert Matcher.normalize("push_ups") == "push_up"
    end

    test "stems ies -> y (butterflies -> butterfly)" do
      assert Matcher.stem_plural("butterflies") == "butterfly"
    end
  end

  describe "collides/2" do
    test "exact match collides" do
      assert Matcher.collides("pistol_squat", "pistol_squat")
    end

    test "free-text name collides with catalog entry" do
      assert Matcher.collides("Bulgarian Split Squats", "bulgarian_split_squat_below_parallel")
    end

    test "Push Ups collides with push_up (compound plural fix)" do
      assert Matcher.collides("Push Ups", "push_up")
    end

    test "bench_press does not collide with pistol_squat" do
      refute Matcher.collides("bench_press", "pistol_squat")
    end

    test "_anything suffix: any core token is enough" do
      assert Matcher.collides("kettlebell_swing", "kettlebell_anything")
    end

    test "_anything: unrelated exercise does not collide" do
      refute Matcher.collides("squat", "kettlebell_anything")
    end

    test "empty extracted string never collides" do
      refute Matcher.collides("", "push_up")
    end
  end
end
