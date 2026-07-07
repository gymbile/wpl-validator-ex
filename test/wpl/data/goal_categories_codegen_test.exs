defmodule WPL.Data.GoalCategoriesCodegenTest do
  use ExUnit.Case, async: true

  alias WPL.Data.GoalCategories

  @root File.cwd!()

  test "exposes all goal-category ids from the vendored JSON" do
    json =
      Path.join(@root, "priv/data/goal-categories.json")
      |> File.read!()
      |> Jason.decode!()

    expected_ids = Enum.map(json["categories"], & &1["id"])
    assert GoalCategories.ids() == expected_ids
  end

  test "includes 'custom' as an id" do
    assert "custom" in GoalCategories.ids()
  end
end
