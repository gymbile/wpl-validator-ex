defmodule WPL.Validator.Rules.EmptyPhasesForTypeTest do
  use ExUnit.Case, async: true

  alias WPL.Validator.Rules.EmptyPhasesForType
  alias WPL.Validator.{Error, WalkContext}

  defp run(plan_map) do
    ctx = %WalkContext{}
    plan = Map.get(plan_map, "plan", plan_map)
    EmptyPhasesForType.enter_plan(ctx, plan).errors |> Enum.reverse()
  end

  describe "EmptyPhasesForType.enter_plan/2" do
    test "emits error when workout plan has zero phases" do
      plan = %{
        "plan" => %{
          "id" => "p",
          "name" => "P",
          "type" => "workout",
          "visibility" => "private",
          "metadata" => %{},
          "goals" => [],
          "phases" => []
        }
      }

      errors = run(plan)
      assert length(errors) == 1

      err = hd(errors)
      assert %Error{
               path: "/plan/phases",
               code: :empty_phases_for_type,
               message: "Plan type 'workout' requires at least one phase",
               severity: :error,
               meta: %{plan_type: "workout"}
             } = err

      # repair_hint (1.7.0)
      assert err.repair_hint != nil
      assert err.repair_hint.action == :add_phases
      assert err.repair_hint.target_path == "/plan/phases"
      assert err.repair_hint.expected_count == 1
      assert err.repair_hint.actual_count == 0
      assert err.repair_hint.expected_shape =~ "workout"
      assert err.repair_hint.context_dsl_example =~ "PHASE"
    end

    test "emits error for hybrid plan with zero phases" do
      plan = %{
        "plan" => %{
          "id" => "p",
          "name" => "P",
          "type" => "hybrid",
          "visibility" => "private",
          "metadata" => %{},
          "goals" => [],
          "phases" => []
        }
      }

      errors = run(plan)
      assert length(errors) == 1
      assert hd(errors).meta == %{plan_type: "hybrid"}
    end

    test "does not emit for nutrition plan with zero phases" do
      plan = %{
        "plan" => %{
          "id" => "p",
          "name" => "P",
          "type" => "nutrition",
          "visibility" => "private",
          "metadata" => %{},
          "goals" => [],
          "phases" => []
        }
      }

      assert run(plan) == []
    end

    test "does not emit when phases is non-empty" do
      plan = %{
        "plan" => %{
          "id" => "p",
          "name" => "P",
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
              "weeks" => []
            }
          ]
        }
      }

      assert run(plan) == []
    end
  end
end
