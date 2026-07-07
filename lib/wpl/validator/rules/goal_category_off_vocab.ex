defmodule WPL.Validator.Rules.GoalCategoryOffVocab do
  @moduledoc false
  use WPL.Validator.Rule

  alias WPL.Data.GoalCategories
  alias WPL.Validator.{Error, WalkContext}

  @impl true
  def enter_plan(ctx, plan) do
    goals = plan |> Map.get("goals", []) |> List.wrap()

    goals
    |> Enum.with_index()
    |> Enum.reduce(ctx, fn {goal, i}, acc ->
      check_goal(acc, goal, "/plan/goals/#{i}")
    end)
  end

  defp check_goal(ctx, goal, path) when is_map(goal) do
    category = Map.get(goal, "category")

    if is_binary(category) and category != "custom" and
         category not in GoalCategories.ids() do
      WalkContext.emit(ctx, %Error{
        path: path,
        code: :goal_category_off_vocab,
        message: "Goal category #{inspect(category)} is not in the recommended vocabulary",
        severity: :warning,
        meta: %{category: category}
      })
    else
      ctx
    end
  end

  defp check_goal(ctx, _goal, _path), do: ctx
end
