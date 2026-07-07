defmodule WPL.Data.GoalCategoriesCodegenTest do
  use ExUnit.Case, async: true

  alias WPL.Data.GoalCategories

  @root File.cwd!()

  test "committed goal_categories.ex equals a fresh codegen run" do
    path = Path.join(@root, "lib/wpl/data/goal_categories.ex")
    before = File.read!(path)

    {_, 0} =
      System.cmd("mix", ["run", "--no-start", "scripts/gen_goal_categories.exs"],
        cd: @root,
        stderr_to_stdout: true
      )

    assert File.read!(path) == before
  end

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
