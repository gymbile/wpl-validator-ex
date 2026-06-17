defmodule WPL.Enforce.RuleEvaluator do
  @moduledoc """
  Evaluates WPL personalization rules against a ClientContext.

  Ported from wpl-validator-ts/src/enforce/rule-evaluator.ts.
  Fail-closed: unknown condition field → UNKNOWN_CONDITION_FIELD diagnostic
  (rule evaluates to not-met). Action without string type → UNKNOWN_ACTION_TYPE
  diagnostic.

  ClientContext is a plain map with atom or string keys. Recognized fields:
  weight_kg, height_cm, age, sex, experience, injuries, equipment, fatigue,
  goals, cycle_day, cycle.
  """

  @known_fields MapSet.new([
                  "weight",
                  "weight_kg",
                  "height",
                  "height_cm",
                  "age",
                  "sex",
                  "gender",
                  "experience",
                  "fitness_level",
                  "injuries",
                  "contraindications",
                  "equipment",
                  "fatigue",
                  "goals",
                  "cycle_day",
                  "cycle_present"
                ])

  @type rule :: map()
  @type client_context :: map()
  @type evaluated_rule :: %{
          rule_id: String.t(),
          condition_met: boolean(),
          actions: [map()],
          condition: map() | nil
        }
  @type diagnostic :: %{
          code: String.t(),
          rule_id: String.t(),
          message: String.t(),
          meta: map()
        }

  @spec evaluate_rules([rule()], client_context()) ::
          %{evaluated: [evaluated_rule()], diagnostics: [diagnostic()]}
  def evaluate_rules(rules, ctx) when is_list(rules) do
    diagnostics = []

    {evaluated, diagnostics} =
      rules
      |> Enum.with_index(1)
      |> Enum.reduce({[], diagnostics}, fn {rule, idx}, {acc_evaluated, acc_diags} ->
        rule_id = Map.get(rule, "id") || Map.get(rule, :id) || "rule_#{idx}"
        condition = Map.get(rule, "condition") || Map.get(rule, :condition)

        {unknown_diags, condition_met} = evaluate_condition(rule_id, condition, ctx)

        actions_raw =
          Map.get(rule, "actions") || Map.get(rule, :actions) || []

        {actions, action_diags} = evaluate_actions(rule_id, actions_raw)

        entry = %{
          rule_id: rule_id,
          condition_met: condition_met,
          actions: actions,
          condition: condition
        }

        {[entry | acc_evaluated], acc_diags ++ unknown_diags ++ action_diags}
      end)

    %{evaluated: Enum.reverse(evaluated), diagnostics: diagnostics}
  end

  def evaluate_rules(_rules, ctx), do: evaluate_rules([], ctx)

  # Returns {diagnostics, condition_met}
  defp evaluate_condition(rule_id, condition, ctx) do
    unknown_fields = collect_unknown_fields(condition, rule_id)
    met = if unknown_fields == [], do: condition_met?(condition, ctx), else: false
    {unknown_fields, met}
  end

  defp collect_unknown_fields(nil, _rule_id), do: []

  defp collect_unknown_fields(condition, rule_id) when is_map(condition) do
    if compound?(condition) do
      inner = Map.get(condition, "conditions") || Map.get(condition, :conditions) || []
      Enum.flat_map(inner, &collect_unknown_fields(&1, rule_id))
    else
      field = Map.get(condition, "field") || Map.get(condition, :field)

      if is_binary(field) and not MapSet.member?(@known_fields, field) do
        [
          %{
            code: "UNKNOWN_CONDITION_FIELD",
            rule_id: rule_id,
            message:
              "condition references field '#{field}' which the enforcement engine cannot resolve — this rule can never fire",
            meta: %{field: field}
          }
        ]
      else
        []
      end
    end
  end

  defp collect_unknown_fields(_condition, _rule_id), do: []

  defp condition_met?(nil, _ctx), do: true

  defp condition_met?(condition, ctx) when is_map(condition) do
    if compound?(condition) do
      compound_match(condition, ctx)
    else
      simple_match(condition, ctx)
    end
  end

  defp condition_met?(_condition, _ctx), do: false

  defp compound?(c) do
    Map.has_key?(c, "operator") or Map.has_key?(c, :operator) or
      Map.has_key?(c, "conditions") or Map.has_key?(c, :conditions)
  end

  defp compound_match(c, ctx) do
    op = Map.get(c, "operator") || Map.get(c, :operator) || "and"
    conditions = Map.get(c, "conditions") || Map.get(c, :conditions) || []

    if op == "or" do
      Enum.any?(conditions, &condition_met?(&1, ctx))
    else
      Enum.all?(conditions, &condition_met?(&1, ctx))
    end
  end

  defp simple_match(c, ctx) do
    op = Map.get(c, "op") || Map.get(c, :op) || "eq"
    field = Map.get(c, "field") || Map.get(c, :field)
    value = Map.get(c, "value") || Map.get(c, :value)
    actual = field_value(field, ctx)
    compare(actual, op, value)
  end

  defp compare(nil, _op, _value), do: false

  defp compare(actual, op, value) do
    case op do
      "eq" ->
        stringify(actual) == stringify(value)

      "neq" ->
        stringify(actual) != stringify(value)

      "gt" ->
        is_number(actual) and is_number(value) and actual > value

      "gte" ->
        is_number(actual) and is_number(value) and actual >= value

      "lt" ->
        is_number(actual) and is_number(value) and actual < value

      "lte" ->
        is_number(actual) and is_number(value) and actual <= value

      "contains" ->
        cond do
          is_list(actual) -> Enum.any?(actual, &(stringify(&1) == stringify(value)))
          is_binary(actual) -> String.contains?(actual, stringify(value) || "")
          true -> false
        end

      "not_contains" ->
        cond do
          is_list(actual) -> not Enum.any?(actual, &(stringify(&1) == stringify(value)))
          is_binary(actual) -> not String.contains?(actual, stringify(value) || "")
          true -> false
        end

      "in" ->
        is_list(value) and
          Enum.any?(value, &(stringify(&1) == stringify(actual)))

      "not_in" ->
        is_list(value) and
          not Enum.any?(value, &(stringify(&1) == stringify(actual)))

      _ ->
        false
    end
  end

  defp stringify(nil), do: ""
  defp stringify(v) when is_binary(v), do: v
  defp stringify(v) when is_number(v), do: to_string(v)
  defp stringify(v) when is_boolean(v), do: to_string(v)
  defp stringify(v) when is_atom(v), do: Atom.to_string(v)
  defp stringify(v), do: to_string(v)

  # Field resolution — mirrors the KNOWN_FIELDS set above exactly.
  # @known_fields must contain every field name handled here.
  defp field_value(field, ctx) do
    case field do
      f when f in ["weight", "weight_kg"] ->
        ctx[:weight_kg] || Map.get(ctx, "weight_kg")

      f when f in ["height", "height_cm"] ->
        ctx[:height_cm] || Map.get(ctx, "height_cm")

      "age" ->
        ctx[:age] || Map.get(ctx, "age")

      f when f in ["sex", "gender"] ->
        ctx[:sex] || Map.get(ctx, "sex")

      f when f in ["experience", "fitness_level"] ->
        ctx[:experience] || Map.get(ctx, "experience")

      f when f in ["injuries", "contraindications"] ->
        ctx[:injuries] || Map.get(ctx, "injuries")

      "equipment" ->
        ctx[:equipment] || Map.get(ctx, "equipment")

      "fatigue" ->
        ctx[:fatigue] || Map.get(ctx, "fatigue")

      "goals" ->
        ctx[:goals] || Map.get(ctx, "goals")

      "cycle_day" ->
        ctx[:cycle_day] || Map.get(ctx, "cycle_day")

      "cycle_present" ->
        cycle = ctx[:cycle] || Map.get(ctx, "cycle")
        if cycle, do: true, else: nil

      _ ->
        nil
    end
  end

  defp evaluate_actions(rule_id, actions) when is_list(actions) do
    Enum.reduce(actions, {[], []}, fn action, {acc_actions, acc_diags} ->
      type = action["type"] || action[:type]

      if is_binary(type) do
        {[normalize_action(action) | acc_actions], acc_diags}
      else
        diag = %{
          code: "UNKNOWN_ACTION_TYPE",
          rule_id: rule_id,
          message: "action has no string `type`; it cannot be applied and is ignored",
          meta: %{action: action}
        }

        {acc_actions, [diag | acc_diags]}
      end
    end)
    |> then(fn {actions, diags} -> {Enum.reverse(actions), Enum.reverse(diags)} end)
  end

  defp evaluate_actions(_rule_id, _actions), do: {[], []}

  defp normalize_action(action) when is_map(action) do
    action
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      kv -> kv
    end)
    |> Map.new()
  end

  @doc "Return only the actions from rules whose condition was met."
  @spec firing_actions([evaluated_rule()]) :: [map()]
  def firing_actions(evaluated) do
    Enum.flat_map(evaluated, fn r ->
      if r.condition_met, do: r.actions, else: []
    end)
  end
end
