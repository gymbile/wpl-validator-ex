defmodule WPL.ValidatorTest do
  use ExUnit.Case, async: true

  alias WPL.Validator
  alias WPL.Validator.Result

  describe "validate/2" do
    test "returns valid result for a minimal valid plan" do
      plan = minimal_plan()
      assert %Result{valid?: true, errors: []} = Validator.validate(plan)
    end

    test "returns invalid for malformed input" do
      result = Validator.validate(%{"not_a_wpl_plan" => true})
      assert %Result{valid?: false, errors: errors} = result
      assert Enum.any?(errors, &(&1.code == :schema_violation))
    end

    test "repair_hints/1 surfaces the hint from :phase_duration_mismatch" do
      plan =
        put_in(minimal_plan(), ["plan", "phases"], [
          %{
            "id" => "phase_1",
            "name" => "Phase 1: Foundation",
            "order" => 1,
            "duration" => %{"value" => 4, "unit" => "weeks"},
            "weeks" => [
              %{
                "id" => "week_1",
                "name" => "W1",
                "order" => 1,
                "days" => [%{"id" => "day_1", "day_of_week" => 1, "type" => "rest"}]
              }
            ]
          }
        ])

      result = Validator.validate(plan)
      hints = Validator.repair_hints(result)
      assert length(hints) >= 1

      phase_hint = Enum.find(hints, &(&1.code == :phase_duration_mismatch))
      assert phase_hint != nil
      assert phase_hint.hint.action == :add_weeks
      assert phase_hint.hint.parent_name == "Phase 1: Foundation"
      assert phase_hint.hint.missing == [2, 3, 4]
    end
  end

  defp minimal_plan do
    %{
      "$schema" => "https://wpl.dev/schemas/wpl/v1.schema.json",
      "version" => "1.6.0",
      "plan" => %{
        "id" => "plan_test",
        "name" => "Test",
        "type" => "workout",
        "visibility" => "private",
        "metadata" => %{},
        "goals" => [],
        "phases" => [
          %{
            "id" => "phase_1",
            "name" => "P1",
            "order" => 1,
            "duration" => %{"value" => 1, "unit" => "weeks"},
            "weeks" => [
              %{
                "id" => "week_1",
                "name" => "W1",
                "order" => 1,
                "days" => [%{"id" => "day_1", "day_of_week" => 1, "type" => "rest"}]
              }
            ]
          }
        ]
      }
    }
  end
end
