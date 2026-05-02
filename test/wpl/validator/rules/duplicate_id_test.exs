defmodule WPL.Validator.Rules.DuplicateIdTest do
  use ExUnit.Case, async: true

  alias WPL.Validator.Pass2

  defp wrap(plan_fields), do: %{"plan" => plan_fields}

  defp base_plan(extra) do
    Map.merge(
      %{
        "id" => "p",
        "name" => "P",
        "type" => "workout",
        "visibility" => "private",
        "metadata" => %{},
        "goals" => []
      },
      extra
    )
  end

  describe "DuplicateId rule" do
    test "detects duplicate day.id within week" do
      input =
        wrap(
          base_plan(%{
            "phases" => [
              %{
                "id" => "phase_1",
                "name" => "P1",
                "order" => 1,
                "duration" => %{"value" => 1, "unit" => "weeks"},
                "weeks" => [
                  %{
                    "id" => "week_1",
                    "days" => [
                      %{"id" => "day_1", "name" => "D1", "type" => "rest"},
                      %{"id" => "day_1", "name" => "D1 again", "type" => "rest"}
                    ]
                  }
                ]
              }
            ]
          })
        )

      errors = Pass2.run(input, [])
      assert length(errors) == 1

      [err] = errors
      assert err.code == :duplicate_id
      assert err.path == "/plan/phases/0/weeks/0/days/1"
      assert err.severity == :error
      assert err.meta.duplicate_id == "day_1"
      assert err.meta.scope == "week:week_1"
      assert err.meta.first_occurrence == "/plan/phases/0/weeks/0/days/0"
    end

    test "detects duplicate week.id within phase" do
      input =
        wrap(
          base_plan(%{
            "phases" => [
              %{
                "id" => "phase_1",
                "name" => "P1",
                "order" => 1,
                "duration" => %{"value" => 2, "unit" => "weeks"},
                "weeks" => [
                  %{
                    "id" => "week_1",
                    "days" => [%{"id" => "d1", "name" => "D1", "type" => "rest"}]
                  },
                  %{
                    "id" => "week_1",
                    "days" => [%{"id" => "d2", "name" => "D2", "type" => "rest"}]
                  }
                ]
              }
            ]
          })
        )

      errors = Pass2.run(input, [])
      assert length(errors) == 1

      [err] = errors
      assert err.meta.duplicate_id == "week_1"
      assert err.meta.scope == "phase:phase_1"
      assert err.meta.first_occurrence == "/plan/phases/0/weeks/0"
    end

    test "detects duplicate phase.id within plan" do
      input =
        wrap(
          base_plan(%{
            "phases" => [
              %{
                "id" => "phase_1",
                "name" => "A",
                "order" => 1,
                "duration" => %{"value" => 1, "unit" => "weeks"},
                "weeks" => []
              },
              %{
                "id" => "phase_1",
                "name" => "B",
                "order" => 2,
                "duration" => %{"value" => 1, "unit" => "weeks"},
                "weeks" => []
              }
            ]
          })
        )

      errors = Pass2.run(input, [])

      # 1 duplicate_id error; also 2 empty_phases_for_type errors skipped (workout type with phases)
      dup_errors = Enum.filter(errors, &(&1.code == :duplicate_id))
      assert length(dup_errors) == 1
      assert hd(dup_errors).meta.scope == "plan"
    end

    test "detects duplicate block.id within day" do
      input =
        wrap(
          base_plan(%{
            "phases" => [
              %{
                "id" => "phase_1",
                "name" => "P1",
                "order" => 1,
                "duration" => %{"value" => 1, "unit" => "weeks"},
                "weeks" => [
                  %{
                    "id" => "week_1",
                    "days" => [
                      %{
                        "id" => "day_1",
                        "name" => "D1",
                        "type" => "workout",
                        "blocks" => [
                          %{"id" => "main", "type" => "main", "order" => 1, "activities" => []},
                          %{"id" => "main", "type" => "main", "order" => 2, "activities" => []}
                        ]
                      }
                    ]
                  }
                ]
              }
            ]
          })
        )

      errors = Pass2.run(input, [])
      dup_errors = Enum.filter(errors, &(&1.code == :duplicate_id))
      assert length(dup_errors) == 1
      assert hd(dup_errors).meta.scope == "day:day_1"
    end

    test "detects duplicate activity.id within day across blocks" do
      input =
        wrap(
          base_plan(%{
            "phases" => [
              %{
                "id" => "phase_1",
                "name" => "P1",
                "order" => 1,
                "duration" => %{"value" => 1, "unit" => "weeks"},
                "weeks" => [
                  %{
                    "id" => "week_1",
                    "days" => [
                      %{
                        "id" => "day_1",
                        "name" => "D1",
                        "type" => "workout",
                        "blocks" => [
                          %{
                            "id" => "main",
                            "type" => "main",
                            "order" => 1,
                            "activities" => [
                              %{"id" => "a1", "type" => "simple", "name" => "walk"}
                            ]
                          },
                          %{
                            "id" => "cool",
                            "type" => "cooldown",
                            "order" => 2,
                            "activities" => [
                              %{"id" => "a1", "type" => "simple", "name" => "stretch"}
                            ]
                          }
                        ]
                      }
                    ]
                  }
                ]
              }
            ]
          })
        )

      errors = Pass2.run(input, [])
      dup_errors = Enum.filter(errors, &(&1.code == :duplicate_id))
      assert length(dup_errors) == 1
      assert hd(dup_errors).meta.duplicate_id == "a1"
      assert hd(dup_errors).meta.scope == "day:day_1"
    end

    test "does not emit for unique IDs" do
      input =
        wrap(
          base_plan(%{
            "phases" => [
              %{
                "id" => "phase_1",
                "name" => "P1",
                "order" => 1,
                "duration" => %{"value" => 1, "unit" => "weeks"},
                "weeks" => [
                  %{
                    "id" => "week_1",
                    "days" => [
                      %{"id" => "day_1", "name" => "D1", "type" => "rest"},
                      %{"id" => "day_2", "name" => "D2", "type" => "rest"}
                    ]
                  }
                ]
              }
            ]
          })
        )

      errors = Pass2.run(input, [])
      dup_errors = Enum.filter(errors, &(&1.code == :duplicate_id))
      assert dup_errors == []
    end
  end
end
