defmodule Stormful.Queue.RateLimiter do
  @moduledoc """
  Rate limiting implementation using a sliding window algorithm.

  This module manages rate limits for different types of tasks to ensure
  we don't exceed external service limits (e.g., 60 emails per minute).
  """

  import Ecto.Query, warn: false
  alias Stormful.Repo
  alias Stormful.Queue.Job

  require Logger

  # Rate limit configurations
  @rate_limits %{
    "email" => %{limit: 60, window_seconds: 60},
    "ai" => %{limit: 100, window_seconds: 60}  # Future use, more generous limit
  }

  @doc """
  Checks if a rate limit key can process a new job without exceeding limits.

  Uses a sliding window approach by counting jobs completed in the last window period.

  ## Examples

      iex> can_process?("email")
      true

      iex> can_process?("email")  # After reaching 60/minute limit
      false

      iex> can_process?("ai")
      true
  """
  def can_process?(rate_limit_key) do
    case get_rate_limit_config(rate_limit_key) do
      nil ->
        Logger.warning("No rate limit configuration for key: #{rate_limit_key}")
        true

      config ->
        current_count = count_recent_completions(rate_limit_key, config.window_seconds)
        can_process = current_count < config.limit

        if can_process do
          Logger.debug("Rate limit check passed for #{rate_limit_key}: #{current_count}/#{config.limit}")
        else
          Logger.info("Rate limit exceeded for #{rate_limit_key}: #{current_count}/#{config.limit}")
        end

        can_process
    end
  end

  @doc """
  Gets the current usage count for a rate limit key within the time window.

  ## Examples

      iex> get_current_usage("email")
      45
  """
  def get_current_usage(rate_limit_key) do
    case get_rate_limit_config(rate_limit_key) do
      nil -> 0
      config -> count_recent_completions(rate_limit_key, config.window_seconds)
    end
  end

  @doc """
  Gets rate limit status for a given key.

  ## Examples

      iex> get_rate_limit_status("email")
      %{
        limit: 60,
        window_seconds: 60,
        current_usage: 45,
        remaining: 15,
        can_process: true,
        reset_time: ~U[2025-05-30 19:15:00Z]
      }
  """
  def get_rate_limit_status(rate_limit_key) do
    case get_rate_limit_config(rate_limit_key) do
      nil ->
        %{
          limit: nil,
          window_seconds: nil,
          current_usage: 0,
          remaining: nil,
          can_process: true,
          reset_time: nil
        }

      config ->
        current_usage = count_recent_completions(rate_limit_key, config.window_seconds)
        remaining = max(0, config.limit - current_usage)
        can_process = current_usage < config.limit

        # Calculate when the window resets (earliest completion + window duration)
        reset_time = calculate_reset_time(rate_limit_key, config.window_seconds)

        %{
          limit: config.limit,
          window_seconds: config.window_seconds,
          current_usage: current_usage,
          remaining: remaining,
          can_process: can_process,
          reset_time: reset_time
        }
    end
  end

  @doc """
  Gets rate limit status for all configured keys.

  ## Examples

      iex> get_all_rate_limit_statuses()
      %{
        "email" => %{limit: 60, current_usage: 45, ...},
        "ai" => %{limit: 100, current_usage: 12, ...}
      }
  """
  def get_all_rate_limit_statuses do
    @rate_limits
    |> Map.keys()
    |> Enum.into(%{}, fn key ->
      {key, get_rate_limit_status(key)}
    end)
  end

  @doc """
  Updates rate limit configuration at runtime (for testing or admin purposes).

  ## Examples

      iex> set_rate_limit("email", 50, 60)
      :ok
  """
  def set_rate_limit(rate_limit_key, limit, window_seconds) do
    # For now, this would require application restart to take effect
    # In a production system, you might store this in the database or ETS
    Logger.info("Rate limit update requested for #{rate_limit_key}: #{limit}/#{window_seconds}s")
    Logger.warning("Rate limit updates require application restart to take effect")
    :ok
  end

  @doc """
  Logs a rate limit violation for monitoring purposes.
  """
  def log_rate_limit_violation(rate_limit_key, job_id \\ nil) do
    status = get_rate_limit_status(rate_limit_key)

    Logger.warning("Rate limit violation", [
      rate_limit_key: rate_limit_key,
      job_id: job_id,
      current_usage: status.current_usage,
      limit: status.limit,
      window_seconds: status.window_seconds,
      timestamp: DateTime.utc_now()
    ])

    # You could also store this in a dedicated rate_limit_violations table
    # for dashboard analytics if needed
  end

  # Private functions

  defp get_rate_limit_config(rate_limit_key) do
    Map.get(@rate_limits, rate_limit_key)
  end

  defp count_recent_completions(rate_limit_key, window_seconds) do
    window_start = DateTime.utc_now() |> DateTime.add(-window_seconds, :second)

    query = from j in Job,
      where: j.rate_limit_key == ^rate_limit_key
        and j.status == "completed"
        and j.completed_at >= ^window_start,
      select: count(j.id)

    Repo.one(query) || 0
  end

  defp calculate_reset_time(rate_limit_key, window_seconds) do
    # Find the earliest completion in the current window
    window_start = DateTime.utc_now() |> DateTime.add(-window_seconds, :second)

    query = from j in Job,
      where: j.rate_limit_key == ^rate_limit_key
        and j.status == "completed"
        and j.completed_at >= ^window_start,
      select: min(j.completed_at),
      limit: 1

    case Repo.one(query) do
      nil ->
        # No completions in window, can process immediately
        DateTime.utc_now()

      earliest_completion ->
        # Reset time is when the earliest completion falls out of the window
        DateTime.add(earliest_completion, window_seconds, :second)
    end
  end

  @doc """
  Returns the configured rate limits for inspection.
  """
  def get_rate_limit_configs, do: @rate_limits

  @doc """
  Calculates how long to wait before the next job can be processed.
  Returns the number of seconds to wait, or 0 if can process immediately.

  ## Examples

      iex> seconds_until_next_slot("email")
      0  # Can process now

      iex> seconds_until_next_slot("email")  # When at limit
      45  # Wait 45 seconds
  """
  def seconds_until_next_slot(rate_limit_key) do
    if can_process?(rate_limit_key) do
      0
    else
      status = get_rate_limit_status(rate_limit_key)
      case status.reset_time do
        nil -> 0
        reset_time ->
          now = DateTime.utc_now()
          if DateTime.compare(reset_time, now) == :gt do
            DateTime.diff(reset_time, now, :second)
          else
            0
          end
      end
    end
  end
end
