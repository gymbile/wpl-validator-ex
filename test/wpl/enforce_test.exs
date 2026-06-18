defmodule WPL.EnforceTest do
  use ExUnit.Case, async: true

  alias WPL.Enforce

  # Minimal plan with one exercise activity in one block
  defp plan_with(exercise_refs) do
    activities =
      Enum.map(exercise_refs, fn ref ->
        %{"type" => "exercise", "exercise_ref" => ref}
      end)

    %{
      "plan" => %{
        "phases" => [
          %{
            "weeks" => [
              %{
                "order" => 1,
                "days" => [
                  %{
                    "day_of_week" => 1,
                    "blocks" => [%{"type" => "main", "activities" => activities}]
                  }
                ]
              }
            ]
          }
        ]
      }
    }
  end

  defp forbid_rule(id, injury, exercise) do
    %{
      "id" => id,
      "condition" => %{"field" => "injuries", "op" => "contains", "value" => injury},
      "actions" => [%{"type" => "forbid_exercise", "exercise" => exercise}]
    }
  end

  describe "enforce/4" do
    test "strips forbidden exercise and reports it in stripped list" do
      plan = plan_with(["pistol_squat", "bench_press"])
      ctx = %{injuries: ["torn_meniscus"]}
      rules = [forbid_rule("forbid_pistol", "torn_meniscus", "pistol_squat")]

      result = Enforce.enforce(plan, ctx, rules)

      refuted_exercises = Enum.map(result.stripped, & &1.exercise)
      assert "pistol_squat" in refuted_exercises

      # bench_press must survive
      surviving =
        result.plan
        |> get_in([
          "plan",
          "phases",
          Access.at(0),
          "weeks",
          Access.at(0),
          "days",
          Access.at(0),
          "blocks",
          Access.at(0),
          "activities"
        ])

      assert Enum.any?(surviving, &(&1["exercise_ref"] == "bench_press"))
      refute Enum.any?(surviving, &(&1["exercise_ref"] == "pistol_squat"))
    end

    test "condition not met — exercise survives" do
      plan = plan_with(["pistol_squat"])
      ctx = %{injuries: []}
      rules = [forbid_rule("forbid_pistol", "torn_meniscus", "pistol_squat")]

      result = Enforce.enforce(plan, ctx, rules)

      assert result.stripped == []

      surviving =
        result.plan
        |> get_in([
          "plan",
          "phases",
          Access.at(0),
          "weeks",
          Access.at(0),
          "days",
          Access.at(0),
          "blocks",
          Access.at(0),
          "activities"
        ])

      assert Enum.any?(surviving, &(&1["exercise_ref"] == "pistol_squat"))
    end

    test "fuzzy name match strips exercise" do
      plan = %{
        "plan" => %{
          "phases" => [
            %{
              "weeks" => [
                %{
                  "order" => 1,
                  "days" => [
                    %{
                      "day_of_week" => 1,
                      "blocks" => [
                        %{
                          "type" => "main",
                          "activities" => [
                            %{"type" => "exercise", "name" => "Bulgarian Split Squats"}
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

      ctx = %{injuries: ["knee_instability"]}

      rules = [
        %{
          "id" => "forbid_bulgarian",
          "condition" => %{
            "field" => "injuries",
            "op" => "contains",
            "value" => "knee_instability"
          },
          "actions" => [
            %{
              "type" => "forbid_exercise",
              "exercise" => "bulgarian_split_squat_below_parallel"
            }
          ]
        }
      ]

      result = Enforce.enforce(plan, ctx, rules)
      assert length(result.stripped) == 1
      assert hd(result.stripped).exercise == "Bulgarian Split Squats"
    end

    test "unknown condition field emits diagnostic and exercise is NOT stripped" do
      plan = plan_with(["pistol_squat"])
      ctx = %{injuries: ["torn_meniscus"]}

      rules = [
        %{
          "id" => "bad_rule",
          "condition" => %{
            "field" => "injures",
            "op" => "contains",
            "value" => "torn_meniscus"
          },
          "actions" => [%{"type" => "forbid_exercise", "exercise" => "pistol_squat"}]
        }
      ]

      result = Enforce.enforce(plan, ctx, rules)
      assert result.stripped == []
      assert Enum.any?(result.diagnostics, &(&1.code == "UNKNOWN_CONDITION_FIELD"))
    end

    test "plan without plan key returns early with no stripped" do
      result = Enforce.enforce(%{}, %{}, [])
      assert result.stripped == []
    end
  end
end
