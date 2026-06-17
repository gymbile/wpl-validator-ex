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
    require_catalog = Keyword.get(ctx.opts, :require_catalog, false)

    Enum.reduce(@ref_kinds, ctx, fn {field, kind, catalog_key}, acc ->
      check_ref(acc, activity, path, field, kind, catalog_key, catalog, require_catalog)
    end)
  end

  defp check_ref(ctx, activity, path, field, kind, catalog_key, catalog, require_catalog) do
    ref_value = Map.get(activity, field)

    if is_binary(ref_value) do
      if catalog == nil do
        if require_catalog do
          WalkContext.emit(ctx, %Error{
            path: "#{path}/#{field}",
            code: :catalog_required,
            message:
              "catalog is required in strict mode but was not provided; " <>
                "cannot resolve #{kind} '#{ref_value}'",
            severity: :error,
            meta: %{ref_kind: kind, ref_value: ref_value}
          })
        else
          ctx
        end
      else
        catalog_set = Map.get(catalog, catalog_key)
        resolved = has_ref?(catalog_set, ref_value)

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
      end
    else
      ctx
    end
  end

  # Case-insensitive membership: try exact first, then lowercase-fold both sides.
  defp has_ref?(nil, _ref), do: false

  defp has_ref?(set, ref) when is_struct(set, MapSet) do
    if MapSet.member?(set, ref) do
      true
    else
      ref_lower = String.downcase(ref)
      Enum.any?(set, fn entry -> String.downcase(entry) == ref_lower end)
    end
  end

  defp has_ref?(_set, _ref), do: false
end
