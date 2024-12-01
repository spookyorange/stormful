defmodule StormfulWeb.Sensicality.BeginLive do
  alias Stormful.Sensicality
  alias Stormful.Sensicality.Sensical

  use StormfulWeb, :live_view
  use StormfulWeb.BaseUtil.Controlful

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_sensical_form(Sensicality.change_sensical(%Sensical{}))
     |> assign_controlful()}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="text-center mb-4 flex flex-col gap-2">
        <.back navigate={~p"/into-the-storm"}>
          Go back
        </.back>

        <p class="text-2xl">
          A new <span class="underline">Sensical</span>⛈
        </p>
        <p class="text-xl">
          Let's start by naming it, shall we?
        </p>
      </div>
      <.form for={@sensical_form} phx-submit="create-sensical" phx-change="change-sensical">
        <.input type="message_area" field={@sensical_form[:title]} />
        <div class="flex w-full justify-center">
          <.button class="mt-4 px-6 bg-indigo-700">Yea[enter]</.button>
        </div>
      </.form>
    </div>
    """
  end

  def handle_event("change-sensical", %{"sensical" => %{"title" => title}}, socket) do
    socket = socket |> assign_sensical_form(Sensicality.change_sensical(%Sensical{title: title}))

    {:noreply, socket}
  end

  def handle_event("create-sensical", %{"sensical" => %{"title" => title}}, socket) do
    # one last time to update the sensical <3
    current_user = socket.assigns.current_user

    sensical = %{title: title, user_id: current_user.id}

    socket =
      case Sensicality.create_sensical(sensical) do
        {:ok, sensical} ->
          push_navigate(socket, to: ~p"/sensicality/#{sensical.id}")
          |> put_flash(:info, "Created successfully ⚡")

        {:error, changeset} ->
          socket |> assign(:sensical_form, to_form(changeset))
      end

    {:noreply, socket}
  end

  def assign_sensical_form(socket, changeset) do
    socket |> assign(:sensical_form, to_form(changeset))
  end

  use StormfulWeb.BaseUtil.KeyboardSupport
end