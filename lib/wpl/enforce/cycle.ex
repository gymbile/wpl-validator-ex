defmodule WPL.Enforce.Cycle do
  @moduledoc """
  Cycle-aware date arithmetic for the Pass-3 enforcement engine.

  Ported from wpl-validator-ts/src/enforce/cycle.ts. Pure functions, no I/O.
  All dates are ISO-8601 strings ("YYYY-MM-DD") treated as UTC midnight.
  """

  @type cycle :: %{
          optional(:last_period_start) => String.t() | nil,
          optional(:length_days) => pos_integer() | nil,
          optional(:pattern) => String.t() | nil
        }

  @day_of_week_map %{
    "monday" => 0,
    "tuesday" => 1,
    "wednesday" => 2,
    "thursday" => 3,
    "friday" => 4,
    "saturday" => 5,
    "sunday" => 6
  }

  @doc "Map a WPL day_of_week token to a 0-based offset from Monday. Returns nil for non-weekday tokens."
  @spec day_of_week_offset(String.t() | integer() | nil) :: 0..6 | nil
  def day_of_week_offset(token) when is_integer(token) do
    if token >= 1 and token <= 7, do: rem(token - 1, 7), else: nil
  end

  def day_of_week_offset(nil), do: nil

  def day_of_week_offset(token) when is_binary(token) do
    Map.get(@day_of_week_map, String.downcase(token))
  end

  def day_of_week_offset(_), do: nil

  @doc """
  Compute the 1-indexed cycle_day at `date` given the client's cycle anchor.
  Returns nil when the cycle is not projectable (irregular or suppressed).
  """
  @spec compute_cycle_day(String.t(), cycle()) :: pos_integer() | nil
  def compute_cycle_day(date, cycle) do
    if projectable?(cycle) do
      d = parse_iso_date(date)

      anchor =
        parse_iso_date(Map.get(cycle, :last_period_start) || Map.get(cycle, "last_period_start"))

      len = Map.get(cycle, :length_days) || Map.get(cycle, "length_days")
      delta = Date.diff(d, anchor)
      mod = rem(rem(delta, len) + len, len)
      mod + 1
    else
      nil
    end
  end

  @doc """
  Compute the calendar date of a plan day given its structural position.
  `day_offset_in_week` is 0-based from Monday (0=Mon, 6=Sun).
  """
  @spec day_date_for_plan_position(String.t(), non_neg_integer(), pos_integer(), 0..6) ::
          String.t()
  def day_date_for_plan_position(
        plan_start,
        weeks_before_phase,
        week_in_phase,
        day_offset_in_week
      ) do
    start = parse_iso_date(plan_start)
    total_day_offset = (weeks_before_phase + (week_in_phase - 1)) * 7 + day_offset_in_week

    start
    |> Date.add(total_day_offset)
    |> Date.to_iso8601()
  end

  defp projectable?(cycle) do
    pattern = Map.get(cycle, :pattern) || Map.get(cycle, "pattern")
    lps = Map.get(cycle, :last_period_start) || Map.get(cycle, "last_period_start")
    len = Map.get(cycle, :length_days) || Map.get(cycle, "length_days")

    pattern not in ["suppressed", "irregular"] and
      is_binary(lps) and
      is_integer(len) and len > 0
  end

  defp parse_iso_date(s) when is_binary(s) do
    case Date.from_iso8601(s) do
      {:ok, date} -> date
      _ -> raise ArgumentError, "cycle: invalid ISO date \"#{s}\""
    end
  end
end
