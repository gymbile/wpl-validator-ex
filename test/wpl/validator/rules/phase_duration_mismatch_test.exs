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
      assert err.meta == %{declared_value: 3, declared_unit: "weeks", weeks_count: 2}
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
  end
end
