defmodule StormfulWeb.Router do
  use StormfulWeb, :router

  import StormfulWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {StormfulWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_api_user
  end

  scope "/", StormfulWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  pipeline :api_public do
    plug :accepts, ["json"]
  end

  # Public API routes
  scope "/api/v1", StormfulWeb.Api do
    pipe_through :api_public

    post "/login", AuthController, :login
  end

  # Authenticated API routes
  scope "/api/v1", StormfulWeb.Api do
    pipe_through :api

    post "/journal", JournalController, :create
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:stormful, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: StormfulWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/api", StormfulWeb do
      pipe_through :api

      # Health check endpoints for monitoring (available in all environments)
      get "/health", HealthController, :index
      get "/health/queue", HealthController, :queue
      get "/health/ping", HealthController, :ping
      get "/health/metrics", HealthController, :metrics
    end
  end

  ## Authentication routes

  scope "/", StormfulWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{StormfulWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/rerequest_confirmation_mail", UserConfirmationInstructionsLive
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", StormfulWeb do
    pipe_through [:browser, :require_authenticated_user, :require_confirmed_user]

    live_session :require_authenticated_user,
      on_mount: [{StormfulWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
      live "/users/profile", UserProfileLive, :edit
      live "/users/outside", UserOutsideLive, :edit

      # Journal routes (new default experience)
      live "/journal", Journaling.JournalLive, :index
      live "/journal/:journal_id", Journaling.JournalLive, :show

      live "/into-the-storm", IntoTheStorm.IndexLive

      live "/sensicality/begin", Sensicality.BeginLive
      live "/sensicality/:sensical_id", Sensicality.ThoughtsLive, :thoughts
      live "/sensicality/:sensical_id/thoughts", Sensicality.ThoughtsLive, :thoughts
      live "/sensicality/:sensical_id/todos", Sensicality.TheSensicalLive, :todos
      live "/sensicality/:sensical_id/heads-ups", Sensicality.TheSensicalLive, :heads_ups
      live "/sensicality/:sensical_id/ai-stuff", Sensicality.AiStuffLive, :ai_stuff

      live "/sensicality/:sensical_id/command-center",
           Sensicality.TheSensicalLive,
           :command_center

      live "/sensicality/:sensical_id/statistics", Sensicality.TheSensicalLive, :statistics
      live "/sensicality/:sensical_id/settings", Sensicality.TheSensicalLive, :settings

      live "/agenda", AgendaLive.Index, :index

      get "/my_winds/:wind_id", WindController, :singular_wind

      # live "/sensicality/:sensical_id/plans/:plan_id/immersive/brainstorm",
      #      StormfulWeb.Immersive.ImmerseSensicalLive,
      #      :brainstorm

      # live "/sensicality/:sensical_id/plans/:plan_id/immersive/managetasks",
      #      StormfulWeb.Immersive.ImmerseSensicalLive,
      #      :managetasks
    end
  end

  scope "/", StormfulWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{StormfulWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
