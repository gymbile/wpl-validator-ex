defmodule WPL.Validator.Rules.UnresolvedRef do
  @moduledoc false
  use WPL.Validator.Rule

  alias WPL.Validator.{Error, WalkContext}

  # {json_field, ref_kind_string, catalog_atom_key}
  @ref_kinds [
    {"exercise_ref", "exercise", :exercises},
    {"meal_ref", "meal", :meals},
    {"meditation_ref", "meditation", :meditations}
  ]

  @impl true
  def enter_activity(ctx, activity, path) do
    catalog = Keyword.get(ctx.opts, :catalog)

    if catalog == nil do
      ctx
    else
      Enum.reduce(@ref_kinds, ctx, fn {field, kind, catalog_key}, acc ->
        check_ref(acc, activity, path, field, kind, catalog_key, catalog)
      end)
    end
  end

  defp check_ref(ctx, activity, path, field, kind, catalog_key, catalog) do
    ref_value = Map.get(activity, field)

    if is_binary(ref_value) do
      catalog_set = Map.get(catalog, catalog_key)
      resolved = is_struct(catalog_set, MapSet) and MapSet.member?(catalog_set, ref_value)

      if resolved do
        ctx
      else
        WalkContext.emit(ctx, %Error{
          path: "#{path}/#{field}",
          code: :unresolved_ref,
          message: "#{kind} '#{ref_value}' not found in catalog",
          severity: :error,
          meta: %{ref_kind: kind, ref_value: ref_value}
        })
      end
    else
      ctx
    end
  end
end
