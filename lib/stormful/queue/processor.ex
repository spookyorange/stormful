defmodule Stormful.Queue.Processor do
  @moduledoc """
  GenServer that processes background jobs from the queue.

  This processor:
  - Fetches jobs ready for processing
  - Checks rate limits before execution
  - Delegates actual work to Worker modules
  - Handles retries and error cases
  - Provides monitoring and health checks
  """

  use GenServer

  alias Stormful.Queue
  alias Stormful.Queue.{Job, RateLimiter, Worker}

  require Logger

  # Default configuration
  @default_config %{
    poll_interval: 5_000,      # Poll for new jobs every 5 seconds
    batch_size: 10,            # Process up to 10 jobs per batch
    max_concurrent: 5,         # Maximum concurrent job processing
    retry_backoff: 30_000      # Wait 30 seconds before retrying failed jobs
  }

  ## Client API

  @doc """
  Starts the processor with optional configuration.

  ## Options

  - `:poll_interval` - How often to check for new jobs (milliseconds)
  - `:batch_size` - Maximum jobs to fetch per batch
  - `:max_concurrent` - Maximum concurrent job processing
  - `:retry_backoff` - Delay before retrying failed jobs (milliseconds)

  ## Examples

      iex> Processor.start_link()
      {:ok, #PID<0.123.0>}

      iex> Processor.start_link(poll_interval: 10_000, batch_size: 5)
      {:ok, #PID<0.124.0>}
  """
  def start_link(opts \\ []) do
    config = Map.merge(@default_config, Map.new(opts))
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Triggers immediate processing of pending jobs (bypasses poll interval).
  """
  def process_now do
    GenServer.cast(__MODULE__, :process_jobs)
  end

  @doc """
  Gets the current processor status and statistics.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Updates processor configuration at runtime.
  """
  def update_config(new_config) do
    GenServer.call(__MODULE__, {:update_config, new_config})
  end

  @doc """
  Gracefully stops the processor.
  """
  def stop do
    GenServer.stop(__MODULE__)
  end

  ## GenServer Implementation

  @impl true
  def init(config) do
    Logger.info("Starting Queue Processor with config: #{inspect(config)}")

    state = %{
      config: config,
      processing_jobs: %{},      # Map of job_id -> task_ref
      stats: %{
        jobs_processed: 0,
        jobs_failed: 0,
        jobs_rate_limited: 0,
        last_processing_time: nil,
        uptime_start: DateTime.utc_now()
      }
    }

    # Schedule first processing cycle
    schedule_next_poll(config.poll_interval)

    {:ok, state}
  end

  @impl true
  def handle_cast(:process_jobs, state) do
    new_state = process_available_jobs(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      config: state.config,
      currently_processing: map_size(state.processing_jobs),
      processing_job_ids: Map.keys(state.processing_jobs),
      stats: state.stats,
      queue_stats: Queue.get_queue_stats(),
      rate_limit_statuses: RateLimiter.get_all_rate_limit_statuses()
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call({:update_config, new_config}, _from, state) do
    updated_config = Map.merge(state.config, Map.new(new_config))
    new_state = %{state | config: updated_config}

    Logger.info("Updated processor config: #{inspect(updated_config)}")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:poll_jobs, state) do
    new_state = process_available_jobs(state)
    schedule_next_poll(state.config.poll_interval)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:job_completed, job_id, result}, state) do
    new_state = handle_job_completion(state, job_id, result)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    # Handle case where a job process dies unexpectedly
    case find_job_by_ref(state.processing_jobs, ref) do
      {job_id, _ref} ->
        case reason do
          :normal ->
            Logger.debug("Job #{job_id} process completed normally")
          reason ->
            Logger.error("Job #{job_id} process died unexpectedly: #{inspect(reason)}")
        end

        new_processing_jobs = Map.delete(state.processing_jobs, job_id)

        # Mark job as failed only if it didn't exit normally
        case reason do
          :normal -> :ok  # Don't mark as failed for normal completion
          _ ->
            case Queue.get_job(job_id) do
              nil -> :ok
              job -> Queue.mark_failed(job, "Process died: #{inspect(reason)}")
            end
        end

        new_stats = case reason do
          :normal -> state.stats  # Don't increment failed counter for normal completion
          _ -> update_stats(state.stats, :jobs_failed)
        end

        {:noreply, %{state | processing_jobs: new_processing_jobs, stats: new_stats}}

      nil ->
        {:noreply, state}
    end
  end

  ## Private Functions

  defp process_available_jobs(state) do
    if can_process_more_jobs?(state) do
      jobs_to_process = fetch_processable_jobs(state)
      Logger.debug("Fetched #{length(jobs_to_process)} jobs for processing")

      new_state = Enum.reduce(jobs_to_process, state, &start_job_processing/2)
      update_last_processing_time(new_state)
    else
      Logger.debug("At maximum concurrent jobs (#{map_size(state.processing_jobs)}/#{state.config.max_concurrent})")
      state
    end
  end

  defp can_process_more_jobs?(state) do
    map_size(state.processing_jobs) < state.config.max_concurrent
  end

  defp fetch_processable_jobs(state) do
    available_slots = state.config.max_concurrent - map_size(state.processing_jobs)
    batch_size = min(available_slots, state.config.batch_size)

    Queue.get_ready_jobs(limit: batch_size)
    |> Enum.filter(&can_process_job?/1)
  end

  defp can_process_job?(job) do
    case job.rate_limit_key do
      nil -> true
      rate_limit_key -> RateLimiter.can_process?(rate_limit_key)
    end
  end

  defp start_job_processing(job, state) do
    case Queue.mark_processing(job) do
      {:ok, updated_job} ->
        Logger.info("Starting processing of job #{job.id} (#{job.task_type})")

        # Start async task to process the job
        task_ref = Process.monitor(spawn_link(fn ->
          result = Worker.process_job(updated_job)
          send(self(), {:job_completed, job.id, result})
        end))

        new_processing_jobs = Map.put(state.processing_jobs, job.id, task_ref)
        %{state | processing_jobs: new_processing_jobs}

      {:error, changeset} ->
        Logger.error("Failed to mark job #{job.id} as processing: #{inspect(changeset.errors)}")
        state
    end
  end

  defp handle_job_completion(state, job_id, result) do
    # Remove from processing jobs
    {_ref, new_processing_jobs} = Map.pop(state.processing_jobs, job_id)

    # Update job status based on result
    new_stats = case result do
      {:ok, _data} ->
        Logger.info("Job #{job_id} completed successfully")
        case Queue.get_job(job_id) do
          nil -> state.stats
          job ->
            Queue.mark_completed(job)
            update_stats(state.stats, :jobs_processed)
        end

      {:error, :rate_limited} ->
        Logger.info("Job #{job_id} skipped due to rate limiting")
        case Queue.get_job(job_id) do
          nil -> state.stats
          job ->
            Queue.mark_rate_limited(job)
            RateLimiter.log_rate_limit_violation(job.rate_limit_key, job.id)
            update_stats(state.stats, :jobs_rate_limited)
        end

      {:error, error} ->
        Logger.error("Job #{job_id} failed: #{inspect(error)}")
        case Queue.get_job(job_id) do
          nil -> state.stats
          job ->
            Queue.mark_failed(job, inspect(error))
            update_stats(state.stats, :jobs_failed)
        end
    end

    %{state | processing_jobs: new_processing_jobs, stats: new_stats}
  end

  defp find_job_by_ref(processing_jobs, ref) do
    Enum.find(processing_jobs, fn {_job_id, job_ref} -> job_ref == ref end)
  end

  defp update_stats(stats, counter) do
    Map.update!(stats, counter, &(&1 + 1))
  end

  defp update_last_processing_time(state) do
    new_stats = Map.put(state.stats, :last_processing_time, DateTime.utc_now())
    %{state | stats: new_stats}
  end

  defp schedule_next_poll(interval) do
    Process.send_after(self(), :poll_jobs, interval)
  end

  ## Health Check Functions

  @doc """
  Performs a health check on the processor.
  Returns :ok if healthy, {:error, reason} if not.
  """
  def health_check do
    try do
      status = get_status()

      cond do
        not Process.alive?(Process.whereis(__MODULE__)) ->
          {:error, "Processor not running"}

        is_nil(status.stats.last_processing_time) ->
          {:error, "Processor has never run"}

        DateTime.diff(DateTime.utc_now(), status.stats.last_processing_time, :minute) > 10 ->
          {:error, "Processor hasn't run in over 10 minutes"}

        true ->
          :ok
      end
    rescue
      e -> {:error, "Health check failed: #{inspect(e)}"}
    end
  end
end
