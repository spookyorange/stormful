defmodule StormfulWeb.HealthController do
  use StormfulWeb, :controller

  alias Stormful.Queue
  alias Stormful.Queue.{Processor, RateLimiter, Worker}

  @doc """
  General health check endpoint for the application.
  """
  def index(conn, _params) do
    health_status = %{
      status: "ok",
      timestamp: DateTime.utc_now(),
      version: Application.spec(:stormful, :vsn) |> to_string(),
      uptime_seconds: System.system_time(:second) - Application.get_env(:stormful, :start_time, System.system_time(:second))
    }

    json(conn, health_status)
  end

  @doc """
  Comprehensive queue system health check.
  """
  def queue(conn, _params) do
    queue_health = %{
      status: determine_overall_queue_health(),
      timestamp: DateTime.utc_now(),
      processor: get_processor_health(),
      worker: get_worker_health(),
      rate_limiter: get_rate_limiter_health(),
      queue_stats: Queue.get_queue_stats(),
      rate_limit_statuses: RateLimiter.get_all_rate_limit_statuses()
    }

    status_code = if queue_health.status == "healthy", do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(queue_health)
  end

  @doc """
  Quick health check endpoint (returns 200 OK if system is operational).
  """
  def ping(conn, _params) do
    case determine_overall_queue_health() do
      "healthy" ->
        send_resp(conn, 200, "OK")
      _ ->
        send_resp(conn, 503, "Service Unavailable")
    end
  end

  @doc """
  Detailed queue metrics for monitoring dashboards.
  """
  def metrics(conn, _params) do
    metrics = %{
      timestamp: DateTime.utc_now(),
      queue: %{
        stats: Queue.get_queue_stats(),
        stats_by_type: Queue.get_stats_by_type()
      },
      processor: %{
        status: Processor.get_status(),
        health: get_processor_health()
      },
      rate_limiter: %{
        statuses: RateLimiter.get_all_rate_limit_statuses(),
        configs: RateLimiter.get_rate_limit_configs()
      },
      worker: %{
        stats: Worker.get_processing_stats(),
        health: get_worker_health()
      }
    }

    json(conn, metrics)
  end

  # Private helper functions

  defp determine_overall_queue_health do
    checks = [
      get_processor_health(),
      get_worker_health(),
      get_rate_limiter_health()
    ]

    if Enum.all?(checks, &(&1.status == "healthy")) do
      "healthy"
    else
      "unhealthy"
    end
  end

  defp get_processor_health do
    case Processor.health_check() do
      :ok ->
        %{
          status: "healthy",
          message: "Processor is running normally"
        }

      {:error, reason} ->
        %{
          status: "unhealthy",
          message: reason
        }
    end
  rescue
    error ->
      %{
        status: "unhealthy",
        message: "Health check failed: #{inspect(error)}"
      }
  end

  defp get_worker_health do
    case Worker.health_check() do
      :ok ->
        %{
          status: "healthy",
          message: "Worker is functioning properly"
        }

      {:error, reason} ->
        %{
          status: "unhealthy",
          message: reason
        }
    end
  rescue
    error ->
      %{
        status: "unhealthy",
        message: "Worker health check failed: #{inspect(error)}"
      }
  end

  defp get_rate_limiter_health do
    try do
      # Test rate limiter by checking configurations
      configs = RateLimiter.get_rate_limit_configs()

      if map_size(configs) > 0 do
        %{
          status: "healthy",
          message: "Rate limiter is configured and operational"
        }
      else
        %{
          status: "unhealthy",
          message: "No rate limit configurations found"
        }
      end
    rescue
      error ->
        %{
          status: "unhealthy",
          message: "Rate limiter health check failed: #{inspect(error)}"
        }
    end
  end
end
