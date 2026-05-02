defmodule WPL.Validator.Rules.InvalidPointsRule do
  @moduledoc false
  use WPL.Validator.Rule

  alias WPL.Validator.{Error, WalkContext}

  @impl true
  def enter_points_rule(ctx, rule, path) do
    ctx
    |> check_action(rule, path)
    |> check_points(rule, path)
  end

  defp check_action(ctx, rule, path) do
    if Map.get(rule, "action") == nil do
      WalkContext.emit(ctx, %Error{
        path: path,
        code: :invalid_points_rule,
        message: "points rule missing 'action'",
        severity: :error,
        meta: %{reason: :missing_action}
      })
    else
      ctx
    end
  end

  defp check_points(ctx, rule, path) do
    case Map.fetch(rule, "points") do
      :error ->
        WalkContext.emit(ctx, %Error{
          path: path,
          code: :invalid_points_rule,
          message: "points rule missing 'points'",
          severity: :error,
          meta: %{reason: :missing_points}
        })

      {:ok, pts} ->
        if is_integer(pts) and pts >= 0 do
          ctx
        else
          WalkContext.emit(ctx, %Error{
            path: path,
            code: :invalid_points_rule,
            message: "points must be non-negative integer",
            severity: :error,
            meta: %{reason: :points_must_be_non_negative_integer}
          })
        end
    end
  end
end
