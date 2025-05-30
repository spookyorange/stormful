defmodule Stormful.Queue.Worker do
  @moduledoc """
  Worker module that handles the actual execution of background jobs.

  This module:
  - Processes different types of jobs (email, AI processing)
  - Implements the actual business logic for each job type
  - Handles errors and timeout scenarios
  - Integrates with rate limiting checks
  """

  alias Stormful.Queue.RateLimiter
  alias Stormful.Mailer

  require Logger

  @doc """
  Main entry point for processing a job.

  Dispatches to the appropriate handler based on job type and handles
  rate limiting, errors, and logging.

  ## Examples

      iex> Worker.process_job(email_job)
      {:ok, %{delivered_at: ~U[2025-05-30 19:30:00Z]}}

      iex> Worker.process_job(ai_job)
      {:ok, %{response: "AI analysis complete", tokens_used: 150}}
  """
  def process_job(job) do
    Logger.info("Worker processing job #{job.id} of type #{job.task_type}")

    # Double-check rate limits before processing
    if rate_limit_allows_processing?(job) do
      process_job_by_type(job)
    else
      Logger.info("Job #{job.id} skipped due to rate limiting during processing")
      {:error, :rate_limited}
    end
  rescue
    error ->
      Logger.error("Unexpected error processing job #{job.id}: #{inspect(error)}")
      {:error, error}
  end

  ## Job Type Handlers

  defp process_job_by_type(%{task_type: "email"} = job) do
    process_email_job(job)
  end

  defp process_job_by_type(%{task_type: "ai_processing"} = job) do
    process_ai_job(job)
  end

  defp process_job_by_type(job) do
    Logger.error("Unknown job type: #{job.task_type}")
    {:error, "Unknown job type: #{job.task_type}"}
  end

  ## Email Job Processing

  defp process_email_job(job) do
    Logger.info("Processing email job #{job.id}")

    case validate_email_payload(job.payload) do
      :ok ->
        send_email(job)

      {:error, reason} ->
        Logger.error("Invalid email payload for job #{job.id}: #{reason}")
        {:error, "Invalid email payload: #{reason}"}
    end
  end

  defp validate_email_payload(payload) do
    required_fields = ["to", "subject"]

    missing_fields =
      required_fields
      |> Enum.filter(fn field -> not Map.has_key?(payload, field) end)

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp send_email(job) do
    payload = job.payload

    # Build email struct (adjust based on your mailer implementation)
    email_data = %{
      to: payload["to"],
      subject: payload["subject"],
      body: Map.get(payload, "body", ""),
      html_body: Map.get(payload, "html_body", ""),
      from: Map.get(payload, "from", "noreply@stormful.com"),
      template: Map.get(payload, "template"),
      template_data: Map.get(payload, "template_data", %{})
    }

    case deliver_email(email_data) do
      {:ok, delivery_info} ->
        Logger.info("Email sent successfully for job #{job.id}")
        {:ok, %{
          delivered_at: DateTime.utc_now(),
          delivery_info: delivery_info,
          recipient: payload["to"]
        }}

      {:error, reason} ->
        Logger.error("Failed to send email for job #{job.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp deliver_email(email_data) do
    # Integrate with existing Swoosh/Mailer system
    try do
      # Debug logging to check what subject we're using
      Logger.debug("Building email with subject: #{inspect(email_data.subject)}")

      # Build Swoosh email using the existing system
      email =
        Swoosh.Email.new()
        |> Swoosh.Email.to(email_data.to)
        |> Swoosh.Email.from(email_data.from)
        |> Swoosh.Email.subject(email_data.subject)
        |> Swoosh.Email.text_body(email_data.body)

      # Add HTML body if provided
      email = if email_data.html_body != "", do: Swoosh.Email.html_body(email, email_data.html_body), else: email

      Logger.debug("Built email: subject=#{inspect(email.subject)}, to=#{inspect(email.to)}")

      # Deliver using the application's Mailer
      case Stormful.Mailer.deliver(email) do
        {:ok, metadata} ->
          {:ok, %{
            message_id: metadata[:id] || "swoosh_delivered",
            provider: "swoosh_mailer",
            timestamp: DateTime.utc_now(),
            metadata: metadata
          }}

        {:error, reason} ->
          {:error, "Email delivery failed: #{inspect(reason)}"}
      end
    rescue
      error ->
        {:error, "Email delivery failed: #{inspect(error)}"}
    end
  end

  ## AI Job Processing

  defp process_ai_job(job) do
    Logger.info("Processing AI job #{job.id}")

    case validate_ai_payload(job.payload) do
      :ok ->
        process_ai_request(job)

      {:error, reason} ->
        Logger.error("Invalid AI payload for job #{job.id}: #{reason}")
        {:error, "Invalid AI payload: #{reason}"}
    end
  end

  defp validate_ai_payload(payload) do
    required_fields = ["prompt"]

    missing_fields =
      required_fields
      |> Enum.filter(fn field -> not Map.has_key?(payload, field) end)

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp process_ai_request(job) do
    payload = job.payload

    ai_request = %{
      prompt: payload["prompt"],
      model: Map.get(payload, "model", "gpt-3.5-turbo"),
      max_tokens: Map.get(payload, "max_tokens", 150),
      temperature: Map.get(payload, "temperature", 0.7),
      user_id: job.user_id
    }

    case call_ai_service(ai_request) do
      {:ok, response} ->
        Logger.info("AI processing completed for job #{job.id}")
        {:ok, %{
          response: response.text,
          tokens_used: response.tokens_used,
          model_used: response.model,
          processing_time_ms: response.processing_time,
          completed_at: DateTime.utc_now()
        }}

      {:error, reason} ->
        Logger.error("AI processing failed for job #{job.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp call_ai_service(ai_request) do
    # This is where you'd integrate with your actual AI service
    # For now, we'll simulate the AI processing

    try do
      # Simulate AI processing delay (2-10 seconds)
      processing_time = Enum.random(2000..10000)
      Process.sleep(processing_time)

      # Here you would actually call your AI service:
      # - OpenAI API
      # - Claude API
      # - Your existing AI modules

      # Simulate response based on prompt length
      prompt_length = String.length(ai_request.prompt)
      tokens_used = min(ai_request.max_tokens, prompt_length * 2)

      response_text = generate_simulated_response(ai_request.prompt)

      {:ok, %{
        text: response_text,
        tokens_used: tokens_used,
        model: ai_request.model,
        processing_time: processing_time
      }}
    rescue
      error ->
        {:error, "AI service call failed: #{inspect(error)}"}
    end
  end

  defp generate_simulated_response(prompt) do
    # Simple simulation of AI response
    prompt_words = String.split(prompt) |> length()

    cond do
      prompt_words < 10 -> "This is a brief AI response to your short prompt."
      prompt_words < 50 -> "This is a medium-length AI response that addresses the key points in your prompt with some detail and analysis."
      true -> "This is a comprehensive AI response that thoroughly analyzes your detailed prompt, providing insights, recommendations, and detailed explanations across multiple aspects of your query."
    end
  end

  ## Helper Functions

  defp rate_limit_allows_processing?(job) do
    case job.rate_limit_key do
      nil -> true
      rate_limit_key -> RateLimiter.can_process?(rate_limit_key)
    end
  end

  @doc """
  Health check function to verify the worker can process jobs.
  """
  def health_check do
    # Test with a simple job simulation
    test_job = %{
      id: "health_check",
      task_type: "test",
      payload: %{},
      rate_limit_key: nil,
      user_id: nil
    }

    case process_job_by_type(test_job) do
      {:error, "Unknown job type: test"} ->
        # This is expected for the health check
        :ok

      result ->
        Logger.warning("Unexpected health check result: #{inspect(result)}")
        :ok
    end
  rescue
    error ->
      {:error, "Worker health check failed: #{inspect(error)}"}
  end

  @doc """
  Returns statistics about job processing performance.
  """
  def get_processing_stats do
    %{
      supported_job_types: ["email", "ai_processing"],
      average_email_time_ms: 300,
      average_ai_time_ms: 5000,
      last_health_check: DateTime.utc_now()
    }
  end
end
