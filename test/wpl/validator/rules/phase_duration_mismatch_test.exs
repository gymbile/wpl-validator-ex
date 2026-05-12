defmodule WPL.Validator.Rules.PhaseDurationMismatchTest do
  use ExUnit.Case, async: true

  alias WPL.Validator.Rules.PhaseDurationMismatch
  alias WPL.Validator.WalkContext

  defp run_on_phase(phase) do
    ctx = %WalkContext{}
    path = "/plan/phases/0"
    PhaseDurationMismatch.enter_phase(ctx, phase, path).errors |> Enum.reverse()
  end

  describe "PhaseDurationMismatch.enter_phase/3" do
    test "flags weeks-unit duration that does not match weeks array length" do
      phase = %{
        "id" => "phase_1",
        "name" => "P1",
        "order" => 1,
        "duration" => %{"value" => 3, "unit" => "weeks"},
        "weeks" => [
          %{"id" => "w1", "days" => [%{"id" => "d1", "name" => "D", "type" => "rest"}]},
          %{"id" => "w2", "days" => [%{"id" => "d2", "name" => "D", "type" => "rest"}]}
        ]
      }

      errors = run_on_phase(phase)
      assert length(errors) == 1

      err = hd(errors)
      assert err.code == :phase_duration_mismatch
      assert err.path == "/plan/phases/0"
      assert err.severity == :warning
      assert err.meta.declared_value == 3
      assert err.meta.declared_unit == "weeks"
      assert err.meta.weeks_count == 2
      assert err.meta.missing_week_numbers == [3]
    end

    test "does not flag matching duration" do
      phase = %{
        "id" => "phase_1",
        "name" => "P1",
        "order" => 1,
        "duration" => %{"value" => 2, "unit" => "weeks"},
        "weeks" => [
          %{"id" => "w1", "days" => []},
          %{"id" => "w2", "days" => []}
        ]
      }

      assert run_on_phase(phase) == []
    end

    test "flags days-unit duration off by more than 1 week" do
      # 30 days = ~4 weeks expected, weeks_count = 1, abs(4-1) = 3 > 1
      phase = %{
        "id" => "phase_1",
        "name" => "P1",
        "order" => 1,
        "duration" => %{"value" => 30, "unit" => "days"},
        "weeks" => [%{"id" => "w1", "days" => []}]
      }

      errors = run_on_phase(phase)
      assert length(errors) == 1
      assert hd(errors).severity == :warning
    end

    test "does not flag days-unit within tolerance (±1 week)" do
      # 14 days = 2 weeks expected, weeks_count = 2: exact match
      phase = %{
        "id" => "phase_1",
        "name" => "P1",
        "order" => 1,
        "duration" => %{"value" => 14, "unit" => "days"},
        "weeks" => [%{"id" => "w1", "days" => []}, %{"id" => "w2", "days" => []}]
      }

      assert run_on_phase(phase) == []
    end

    test "does not flag empty weeks array" do
      phase = %{
        "id" => "phase_1",
        "name" => "P1",
        "order" => 1,
        "duration" => %{"value" => 5, "unit" => "weeks"},
        "weeks" => []
      }

      assert run_on_phase(phase) == []
    end

    test "does not flag when duration is absent" do
      phase = %{
        "id" => "phase_1",
        "name" => "P1",
        "order" => 1,
        "weeks" => [%{"id" => "w1", "days" => []}]
      }

      assert run_on_phase(phase) == []
    end

    # ---- repair_hint (1.7.0) --------------------------------------------

    test "attaches repair_hint with missing week numbers when under-emitted" do
      phase = %{
        "id" => "phase_1",
        "name" => "Phase 1: Foundation",
        "order" => 1,
        "duration" => %{"value" => 4, "unit" => "weeks"},
        "weeks" => [%{"id" => "w1", "days" => [%{"id" => "d1", "name" => "D", "type" => "rest"}]}]
      }

      errors = run_on_phase(phase)
      assert length(errors) == 1
      hint = hd(errors).repair_hint

      assert hint != nil
      assert hint.action == :add_weeks
      assert hint.target_path == "/plan/phases/0/weeks"
      assert hint.parent_name == "Phase 1: Foundation"
      assert hint.expected_count == 4
      assert hint.actual_count == 1
      assert hint.missing == [2, 3, 4]
      assert hint.context_dsl_example =~ "WEEK {n}:"
      assert hint.context_dsl_example =~ "DAY Monday"
    end

    test "emits error but no missing list when over-emitted" do
      phase = %{
        "id" => "phase_1",
        "name" => "P1",
        "order" => 1,
        "duration" => %{"value" => 2, "unit" => "weeks"},
        "weeks" => [
          %{"id" => "w1", "days" => []},
          %{"id" => "w2", "days" => []},
          %{"id" => "w3", "days" => []},
          %{"id" => "w4", "days" => []}
        ]
      }

      errors = run_on_phase(phase)
      assert length(errors) == 1
      hint = hd(errors).repair_hint
      assert hint != nil
      assert hint.expected_count == 2
      assert hint.actual_count == 4
      assert hint.missing == nil
      assert hint.context_dsl_example == nil
    end

    test "lists all 11 missing weeks for a 12-week phase with only week 1" do
      phase = %{
        "id" => "phase_1",
        "name" => "Couch-to-5K",
        "order" => 1,
        "duration" => %{"value" => 12, "unit" => "weeks"},
        "weeks" => [%{"id" => "w1", "days" => [%{"id" => "d1", "name" => "D", "type" => "rest"}]}]
      }

      errors = run_on_phase(phase)
      assert length(errors) == 1
      assert hd(errors).repair_hint.missing == [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
      assert hd(errors).meta.missing_week_numbers == [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    end
  end
end
