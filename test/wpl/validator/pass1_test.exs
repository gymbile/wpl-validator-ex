defmodule WPL.Validator.Pass1Test do
  use ExUnit.Case, async: true

  alias WPL.Validator.Pass1

  describe "run/1" do
    test "returns no errors for a minimal valid plan" do
      plan = minimal_plan()
      assert Pass1.run(plan) == []
    end

    test "emits schema_violation with RFC 6901 path for unknown enum value" do
      plan = %{
        minimal_plan()
        | "plan" => Map.put(minimal_plan()["plan"], "type", "intergalactic_disco")
      }

      errors = Pass1.run(plan)

      assert length(errors) > 0

      enum_err = Enum.find(errors, &(&1.path == "/plan/type"))
      assert enum_err != nil
      assert enum_err.code == :schema_violation
      assert enum_err.severity == :error
      assert enum_err.meta.keyword == "enum"
    end

    test "emits schema_violation for missing required field id" do
      plan_without_id =
        minimal_plan()
        |> Map.update!("plan", &Map.delete(&1, "id"))

      errors = Pass1.run(plan_without_id)

      missing_id =
        Enum.find(errors, fn e ->
          e.code == :schema_violation and e.path == "/plan" and e.meta.keyword == "required"
        end)

      assert missing_id != nil
    end
  end

  defp minimal_plan do
    %{
      "$schema" => "https://wpl.dev/schemas/wpl/v1.schema.json",
      "version" => "1.0.0",
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
