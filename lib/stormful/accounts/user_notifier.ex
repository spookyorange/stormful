defmodule Stormful.Accounts.UserNotifier do
  import Swoosh.Email

  alias Stormful.Mailer
  alias Stormful.Queue

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Stormful", StormfulWeb.Endpoint.config(:email_from)})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  # Queues the email for background delivery using our queue system.
  defp deliver_via_queue(recipient, subject, body, opts \\ []) do
    email_payload = %{
      "to" => recipient,
      "subject" => subject,
      "body" => body,
      "from" => "Stormful <#{StormfulWeb.Endpoint.config(:email_from)}>",
      "template" => nil,
      "html_body" => ""
    }

    case Queue.enqueue_email(email_payload, opts) do
      {:ok, job} ->
        {:ok, %{job_id: job.id, recipient: recipient, subject: subject}}

      {:error, changeset} ->
        # Fallback to direct delivery if queue fails
        deliver(recipient, subject, body)
    end
  end

  @doc """
  Deliver instructions to confirm account.
  Now uses background processing for better user experience!
  """
  def deliver_confirmation_instructions(user, url) do
    body = """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """

    deliver_via_queue(
      user.email,
      "Confirmation instructions",
      body,
      user_id: user.id
    )
  end

  @doc """
  Deliver instructions to reset a user password.
  Now uses background processing for better user experience!
  """
  def deliver_reset_password_instructions(user, url) do
    body = """

    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """

    deliver_via_queue(
      user.email,
      "Reset password instructions",
      body,
      user_id: user.id
    )
  end

  @doc """
  Deliver instructions to update a user email.
  Now uses background processing for better user experience!
  """
  def deliver_update_email_instructions(user, url) do
    body = """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """

    deliver_via_queue(
      user.email,
      "Update email instructions",
      body,
      user_id: user.id
    )
  end

  @doc """
  Send a welcome email to new users.
  Uses our queue system for non-blocking delivery!
  """
  def deliver_welcome_email(user) do
    body = """

    ==============================

    Welcome to Stormful, #{user.email}!

    We're excited to have you on board. Here's what you can do next:

    • Explore your dashboard
    • Set up your profile
    • Start your first project

    If you have any questions, don't hesitate to reach out!

    Best regards,
    The Stormful Team

    ==============================
    """

    deliver_via_queue(
      user.email,
      "Welcome to Stormful! 🎉",
      body,
      user_id: user.id
    )
  end

  @doc """
  For backwards compatibility or urgent emails that need immediate delivery.
  """
  def deliver_immediately(recipient, subject, body) do
    deliver(recipient, subject, body)
  end

  @doc """
  Get the status of a queued email job.
  """
  def get_email_status(job_id) do
    case Queue.get_job(job_id) do
      nil -> {:error, :not_found}
      job -> {:ok, %{status: job.status, attempts: job.attempts, error: job.error_message}}
    end
  end
end
