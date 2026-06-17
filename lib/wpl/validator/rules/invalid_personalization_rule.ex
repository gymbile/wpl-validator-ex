defmodule WPL.Validator.Rules.InvalidPersonalizationRule do
  @moduledoc false
  use WPL.Validator.Rule

  alias WPL.Validator.{Error, WalkContext}

  @action_types MapSet.new([
                  "forbid_exercise",
                  "modify_intensity",
                  "add_warmup_time",
                  "increase_rest",
                  "reduce_sets",
                  "reduce_reps",
                  "replace_exercise",
                  "exclude_exercise",
                  "modify_exercise",
                  "use_schedule",
                  "add_activity"
                ])

  @action_scopes MapSet.new(["activity", "block", "day", "week", "phase", "plan"])

  @impl true
  def enter_personalization_rule(ctx, rule, path) do
    ctx
    |> validate_condition(Map.get(rule, "condition"), path)
    |> validate_actions(Map.get(rule, "actions"), path)
  end

  # -----------------------------------------------------------------------
  # Condition validation
  # -----------------------------------------------------------------------

  defp validate_condition(ctx, nil, _path), do: ctx

  defp validate_condition(ctx, cond, path) when is_map(cond) do
    has_operator = Map.has_key?(cond, "operator")
    has_conditions = Map.has_key?(cond, "conditions")

    if has_operator or has_conditions do
      validate_compound_condition(ctx, cond, path)
    else
      validate_simple_condition(ctx, cond, path)
    end
  end

  defp validate_condition(ctx, _cond, path) do
    emit_invalid_condition(ctx, path, "condition must be an object")
  end

  defp validate_compound_condition(ctx, cond, path) do
    operator = Map.get(cond, "operator")

    if operator != "and" and operator != "or" do
      emit_invalid_condition(ctx, path, "compound condition operator must be 'and' or 'or'")
    else
      conditions = Map.get(cond, "conditions")

      if not is_list(conditions) or conditions == [] do
        emit_invalid_condition(
          ctx,
          path,
          "compound condition requires non-empty conditions array"
        )
      else
        Enum.reduce(conditions, ctx, fn inner, acc ->
          validate_condition(acc, inner, path)
        end)
      end
    end
  end

  defp validate_simple_condition(ctx, cond, path) do
    has_field = Map.has_key?(cond, "field")
    has_op = Map.has_key?(cond, "op")

    if not has_field and not has_op do
      emit_invalid_condition(ctx, path, "condition must have 'field' or 'op'")
    else
      ctx
    end
  end

  defp emit_invalid_condition(ctx, path, message) do
    WalkContext.emit(ctx, %Error{
      path: path,
      code: :invalid_personalization_rule,
      message: message,
      severity: :error,
      meta: %{reason: :invalid_condition}
    })
  end

  # -----------------------------------------------------------------------
  # Actions validation
  # -----------------------------------------------------------------------

  defp validate_actions(ctx, actions, path) when is_list(actions) do
    ctx =
      if actions == [] do
        WalkContext.emit(ctx, %Error{
          path: path,
          code: :invalid_personalization_rule,
          message: "actions must be a non-empty list",
          severity: :error,
          meta: %{reason: :actions_must_be_non_empty_list}
        })
      else
        ctx
      end

    actions
    |> Enum.with_index()
    |> Enum.reduce(ctx, fn {action, i}, acc ->
      validate_action(acc, action, "#{path}/actions/#{i}")
    end)
  end

  defp validate_actions(ctx, _actions, _path), do: ctx

  defp validate_action(ctx, action, apath) when is_map(action) do
    ctx
    |> validate_action_type(action, apath)
    |> validate_action_scope(action, apath)
  end

  defp validate_action(ctx, _action, _apath), do: ctx

  defp validate_action_type(ctx, action, apath) do
    case Map.get(action, "type") do
      nil ->
        ctx

      t when is_binary(t) ->
        if MapSet.member?(@action_types, t) do
          ctx
        else
          WalkContext.emit(ctx, %Error{
            path: apath,
            code: :invalid_personalization_rule,
            message: "invalid action type '#{t}'",
            severity: :error,
            meta: %{reason: :invalid_action_type, field: "type", value: t}
          })
        end

      t ->
        WalkContext.emit(ctx, %Error{
          path: apath,
          code: :invalid_personalization_rule,
          message: "invalid action type '#{t}'",
          severity: :error,
          meta: %{reason: :invalid_action_type, field: "type", value: t}
        })
    end
  end

  defp validate_action_scope(ctx, action, apath) do
    case Map.get(action, "scope") do
      nil ->
        ctx

      s when is_binary(s) ->
        if MapSet.member?(@action_scopes, s) do
          ctx
        else
          WalkContext.emit(ctx, %Error{
            path: apath,
            code: :invalid_personalization_rule,
            message: "invalid action scope '#{s}'",
            severity: :error,
            meta: %{reason: :invalid_action_scope, field: "scope", value: s}
          })
        end

      s ->
        WalkContext.emit(ctx, %Error{
          path: apath,
          code: :invalid_personalization_rule,
          message: "invalid action scope '#{s}'",
          severity: :error,
          meta: %{reason: :invalid_action_scope, field: "scope", value: s}
        })
    end
  end
end
