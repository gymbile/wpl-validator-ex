defmodule WPL.Enforce.CycleTest do
  use ExUnit.Case, async: true

  alias WPL.Enforce.Cycle

  describe "compute_cycle_day/2" do
    test "same day as last_period_start is cycle day 1" do
      cycle = %{
        last_period_start: "2026-01-05",
        length_days: 28,
        pattern: "regular"
      }

      assert Cycle.compute_cycle_day("2026-01-05", cycle) == 1
    end

    test "one day after start is cycle day 2" do
      cycle = %{last_period_start: "2026-01-05", length_days: 28, pattern: "regular"}
      assert Cycle.compute_cycle_day("2026-01-06", cycle) == 2
    end

    test "wraps around at cycle length" do
      cycle = %{last_period_start: "2026-01-05", length_days: 28, pattern: "regular"}
      # day 28 from start = cycle day 1 of next cycle
      assert Cycle.compute_cycle_day("2026-02-02", cycle) == 1
    end

    test "returns nil for irregular cycle" do
      cycle = %{last_period_start: "2026-01-05", length_days: 28, pattern: "irregular"}
      assert Cycle.compute_cycle_day("2026-01-06", cycle) == nil
    end

    test "returns nil for suppressed cycle" do
      cycle = %{last_period_start: "2026-01-05", length_days: 28, pattern: "suppressed"}
      assert Cycle.compute_cycle_day("2026-01-06", cycle) == nil
    end

    test "returns nil when last_period_start is nil" do
      cycle = %{length_days: 28, pattern: "regular"}
      assert Cycle.compute_cycle_day("2026-01-06", cycle) == nil
    end
  end

  describe "day_date_for_plan_position/4" do
    test "week 1 day 0 offset from Monday plan start is the same date" do
      # planStart 2026-01-05 (Monday), weeksBeforePhase=0, weekInPhase=1, dayOffset=0
      assert Cycle.day_date_for_plan_position("2026-01-05", 0, 1, 0) == "2026-01-05"
    end

    test "week 1 day 1 is Tuesday" do
      assert Cycle.day_date_for_plan_position("2026-01-05", 0, 1, 1) == "2026-01-06"
    end

    test "week 2 day 0 is 7 days after plan start" do
      assert Cycle.day_date_for_plan_position("2026-01-05", 0, 2, 0) == "2026-01-12"
    end
  end

  describe "day_of_week_offset/1" do
    test "monday -> 0" do
      assert Cycle.day_of_week_offset("monday") == 0
    end

    test "case-insensitive" do
      assert Cycle.day_of_week_offset("Monday") == 0
    end

    test "integer 1 (Monday convention) -> 0" do
      assert Cycle.day_of_week_offset(1) == 0
    end

    test "integer 7 -> 6" do
      assert Cycle.day_of_week_offset(7) == 6
    end

    test "nil -> nil" do
      assert Cycle.day_of_week_offset(nil) == nil
    end

    test "REST -> nil" do
      assert Cycle.day_of_week_offset("REST") == nil
    end
  end
end
