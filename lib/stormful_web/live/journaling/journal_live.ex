defmodule StormfulWeb.Journaling.JournalLive do
  use StormfulWeb, :live_view

  alias Stormful.Journaling
  alias Stormful.FlowingThoughts
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    # Get all user's journals
    journals = Journaling.list_journals(current_user.id)

    case journals do
      [] ->
        # No journals yet - show empty state
        {:ok,
         socket
         |> assign(journal: nil)
         |> assign(journals: [])
         |> assign(current_user: current_user)
         |> assign_modal_state()
         |> stream(:winds, [])}

      [journal | _] ->
        # Use first journal as default
        winds = get_journal_winds(journal.id, current_user.id)

        # Subscribe to journal updates
        FlowingThoughts.subscribe_to_journal(journal)

        {:ok,
         socket
         |> assign(journal: journal)
         |> assign(journals: journals)
         |> assign(current_user: current_user)
         |> assign_modal_state()
         |> stream(:winds, winds)}
    end
  end

  @impl true
  def handle_info({:new_wind, wind}, socket) do
    {:noreply,
     socket
     |> stream_insert(:winds, wind, at: 0)}
  end

  @impl true
  def handle_event("edit_current_journal", _, socket) do
    if socket.assigns.journal do
      {:noreply,
       socket
       |> assign(:show_edit_modal, true)
       |> assign_edit_form(socket.assigns.journal)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("create_new_journal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_create_modal, true)
     |> assign_create_form()}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, close_all_modals(socket)}
  end

  @impl true
  def handle_event("validate_journal", %{"journal" => journal_params}, socket) do
    changeset =
      %Stormful.Journaling.Journal{}
      |> Journaling.change_journal(journal_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :journal_form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate_edit_journal", %{"journal" => journal_params}, socket) do
    changeset =
      socket.assigns.journal
      |> Journaling.change_journal(journal_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :edit_journal_form, to_form(changeset))}
  end

  @impl true
  def handle_event("create_journal", %{"journal" => journal_params}, socket) do
    current_user = socket.assigns.current_user

    attrs = Map.put(journal_params, "user_id", current_user.id)

    case Journaling.create_journal(attrs) do
      {:ok, journal} ->
        # Update the journals list and navigate to the new journal
        updated_journals = Journaling.list_journals(current_user.id)

        {:noreply,
         socket
         |> assign(journals: updated_journals)
         |> close_all_modals()
         |> put_flash(:info, "Journal created!")
         |> push_navigate(to: ~p"/journal/#{journal.id}")}

      {:error, :max_journals_reached} ->
        {:noreply,
         socket
         |> put_flash(:error, "You can only have up to 3 journals")}

      {:error, changeset} ->
        {:noreply, assign(socket, :journal_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("update_journal", %{"journal" => journal_params}, socket) do
    case Journaling.update_journal(socket.assigns.journal, journal_params) do
      {:ok, updated_journal} ->
        # Update the journals list
        updated_journals = Journaling.list_journals(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(journal: updated_journal)
         |> assign(journals: updated_journals)
         |> close_all_modals()
         |> put_flash(:info, "Journal updated!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :edit_journal_form, to_form(changeset))}
    end
  end

  defp assign_modal_state(socket) do
    socket
    |> assign(:show_create_modal, false)
    |> assign(:show_edit_modal, false)
    |> assign(:show_delete_modal, false)
    |> assign_create_form()
  end

  defp assign_create_form(socket) do
    changeset = Journaling.change_journal(%Stormful.Journaling.Journal{})
    assign(socket, :journal_form, to_form(changeset))
  end

  defp assign_edit_form(socket, journal) do
    changeset = Journaling.change_journal(journal)
    assign(socket, :edit_journal_form, to_form(changeset))
  end

  defp close_all_modals(socket) do
    socket
    |> assign(:show_create_modal, false)
    |> assign(:show_edit_modal, false)
    |> assign(:show_delete_modal, false)
  end

  defp get_journal_winds(journal_id, user_id) do
    # For now, let's get the most recent 50 winds
    # Later we'll implement proper infinite scroll pagination
    FlowingThoughts.list_winds_by_journal(journal_id, user_id, :desc, 50)
  end
end
