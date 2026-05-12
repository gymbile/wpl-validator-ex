defmodule WPL.Validator.Rules.ActivityBlockMismatchTest do
  use ExUnit.Case, async: true

  alias WPL.Validator.Pass2
  alias WPL.Validator.Error

  defp run(block_type, activity_type) do
    input = %{
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
            "weeks" => [
              %{
                "id" => "week_1",
                "name" => "Week 1",
                "order" => 1,
                "days" => [
                  %{
                    "id" => "day_1",
                    "name" => "D1",
                    "type" => "training",
                    "blocks" => [
                      %{
                        "id" => "block_1",
                        "type" => block_type,
                        "order" => 1,
                        "activities" => [
                          %{"id" => "act_1", "type" => activity_type}
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

    Pass2.run(input, [])
    |> Enum.filter(&(&1.code == :activity_block_mismatch))
  end

  describe "ActivityBlockMismatch" do
    # --- violation cases ---

    test "emits error for nutrition in cooldown block" do
      errors = run("cooldown", "nutrition")
      assert length(errors) == 1
      [err] = errors

      assert %Error{
               code: :activity_block_mismatch,
               path: "/plan/phases/0/weeks/0/days/0/blocks/0/activities/0",
               severity: :error
             } = err

      assert err.meta.activity_type == "nutrition"
      assert err.meta.block_type == "cooldown"
      assert "nutrition" not in err.meta.allowed
      assert String.contains?(err.message, "'nutrition'")
      assert String.contains?(err.message, "'cooldown'")
    end

    test "emits error for exercise in nutrition block" do
      errors = run("nutrition", "exercise")
      assert length(errors) == 1
      assert hd(errors).meta.activity_type == "exercise"
      assert hd(errors).meta.block_type == "nutrition"
    end

    test "emits error for nutrition in warmup block" do
      errors = run("warmup", "nutrition")
      assert length(errors) == 1
      assert hd(errors).meta.activity_type == "nutrition"
      assert hd(errors).meta.block_type == "warmup"
    end

    test "emits error for exercise in meditation block" do
      errors = run("meditation", "exercise")
      assert length(errors) == 1
      assert hd(errors).meta.activity_type == "exercise"
    end

    test "emits error for nutrition in education block" do
      errors = run("education", "nutrition")
      assert length(errors) == 1
      assert hd(errors).meta.activity_type == "nutrition"
    end

    test "emits error for meditation in assessment block" do
      errors = run("assessment", "meditation")
      assert length(errors) == 1
      assert hd(errors).meta.activity_type == "meditation"
    end

    # --- allowed cases ---

    test "does not emit for exercise in main block" do
      assert run("main", "exercise") == []
    end

    test "does not emit for cardio in main block" do
      assert run("main", "cardio") == []
    end

    test "does not emit for cardio in warmup block" do
      assert run("warmup", "cardio") == []
    end

    test "does not emit for recovery in warmup block" do
      assert run("warmup", "recovery") == []
    end

    test "does not emit for recovery in cooldown block" do
      assert run("cooldown", "recovery") == []
    end

    test "does not emit for cardio in cooldown block" do
      assert run("cooldown", "cardio") == []
    end

    test "does not emit for meditation in cooldown block" do
      assert run("cooldown", "meditation") == []
    end

    test "does not emit for nutrition in nutrition block" do
      assert run("nutrition", "nutrition") == []
    end

    test "does not emit for meditation in meditation block" do
      assert run("meditation", "meditation") == []
    end

    test "does not emit for exercise in assessment block" do
      assert run("assessment", "exercise") == []
    end

    test "does not emit for cardio in assessment block" do
      assert run("assessment", "cardio") == []
    end

    test "does not emit for habit in education block" do
      assert run("education", "habit") == []
    end

    # --- escape hatches accepted everywhere ---

    test "does not emit for simple in warmup block" do
      assert run("warmup", "simple") == []
    end

    test "does not emit for simple in cooldown block" do
      assert run("cooldown", "simple") == []
    end

    test "does not emit for simple in nutrition block" do
      assert run("nutrition", "simple") == []
    end

    test "does not emit for sub_plan in meditation block" do
      assert run("meditation", "sub_plan") == []
    end

    test "does not emit for sub_plan in education block" do
      assert run("education", "sub_plan") == []
    end

    # --- unknown block type is ignored ---

    test "does not emit for unknown block type" do
      assert run("custom_block", "exercise") == []
    end

    # --- repair_hint (1.7.0) ---

    test "attaches repair_hint with action=:fix_activity and allowed_values" do
      [err] = run("warmup", "nutrition")
      hint = err.repair_hint
      assert hint != nil
      assert hint.action == :fix_activity
      assert hint.target_path == "/plan/phases/0/weeks/0/days/0/blocks/0/activities/0"
      assert "cardio" in hint.allowed_values
      assert "recovery" in hint.allowed_values
      refute "nutrition" in hint.allowed_values
      assert hint.expected_shape =~ "warmup"
    end
  end
end
