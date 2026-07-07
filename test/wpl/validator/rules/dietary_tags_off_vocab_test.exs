defmodule WPL.Validator.Rules.DietaryTagsOffVocabTest do
  use ExUnit.Case, async: true

  alias WPL.Validator.{Pass2, Rules.DietaryTagsOffVocab, WalkContext}

  defp run_on_activity(activity) do
    ctx = %WalkContext{}
    path = "/plan/phases/0/weeks/0/days/0/blocks/0/activities/0"
    DietaryTagsOffVocab.enter_activity(ctx, activity, path).errors |> Enum.reverse()
  end

  describe "DietaryTagsOffVocab.enter_activity/3" do
    test "known dietary tag emits no warnings" do
      activity = %{
        "id" => "a1",
        "type" => "nutrition",
        "dietary_tags" => ["vegetarian"]
      }

      assert run_on_activity(activity) == []
    end

    test "all known tags emit no warnings" do
      activity = %{
        "id" => "a1",
        "type" => "nutrition",
        "dietary_tags" => ["vegetarian", "vegan", "gluten_free", "dairy_free"]
      }

      assert run_on_activity(activity) == []
    end

    test "off-vocab tag emits exactly one warning with correct code and severity" do
      activity = %{
        "id" => "a1",
        "type" => "nutrition",
        "dietary_tags" => ["keto"]
      }

      errors = run_on_activity(activity)
      assert length(errors) == 1
      err = hd(errors)
      assert err.code == :dietary_tags_off_vocab
      assert err.severity == :warning
    end

    test "two off-vocab tags emit two warnings" do
      activity = %{
        "id" => "a1",
        "type" => "nutrition",
        "dietary_tags" => ["keto", "paleo"]
      }

      errors = run_on_activity(activity)
      assert length(errors) == 2
      assert Enum.all?(errors, &(&1.severity == :warning))
    end

    test "mix of known and unknown emits only for unknown" do
      activity = %{
        "id" => "a1",
        "type" => "nutrition",
        "dietary_tags" => ["vegetarian", "keto"]
      }

      errors = run_on_activity(activity)
      assert length(errors) == 1
      assert hd(errors).meta.tag == "keto"
    end

    test "no dietary_tags key emits no warnings" do
      activity = %{"id" => "a1", "type" => "nutrition"}
      assert run_on_activity(activity) == []
    end

    test "empty dietary_tags list emits no warnings" do
      activity = %{"id" => "a1", "type" => "nutrition", "dietary_tags" => []}
      assert run_on_activity(activity) == []
    end

    test "non-nutrition activity is skipped even with dietary_tags" do
      activity = %{
        "id" => "a1",
        "type" => "exercise",
        "dietary_tags" => ["keto"]
      }

      assert run_on_activity(activity) == []
    end

    test "plan with only dietary-tag warnings is still valid end-to-end" do
      # Build a minimal plan doc with an off-vocab dietary_tag and run pass2 directly
      # (bypassing schema validation, which predates the dietary_tags field).
      # Confirms that :warning-severity results from DietaryTagsOffVocab don't
      # cause the plan to be considered invalid.
      plan_doc = %{
        "plan" => %{
          "id" => "plan_test",
          "goals" => [],
          "phases" => [
            %{
              "id" => "phase_1",
              "order" => 1,
              "weeks" => [
                %{
                  "id" => "week_1",
                  "order" => 1,
                  "days" => [
                    %{
                      "id" => "day_1",
                      "day_of_week" => 1,
                      "type" => "training",
                      "blocks" => [
                        %{
                          "id" => "block_1",
                          "type" => "nutrition",
                          "order" => 1,
                          "activities" => [
                            %{
                              "id" => "n_1",
                              "type" => "nutrition",
                              "dietary_tags" => ["keto"]
                            }
                          ]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
      }

      errors = Pass2.run(plan_doc, [])
      valid? = Enum.all?(errors, &(&1.severity != :error))
      assert valid? == true
      warnings = Enum.filter(errors, &(&1.severity == :warning))
      assert Enum.any?(warnings, &(&1.code == :dietary_tags_off_vocab))
    end
  end
end
