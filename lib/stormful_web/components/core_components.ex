defmodule StormfulWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as modals, tables, and
  forms. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  import StormfulWeb.Gettext

  @doc """
  Renders a modal.

  ## Examples

  <.modal id="confirm-modal">
    This is a modal.
  </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

  <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
    This is another modal.
  </.modal>
  """

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :class, :string, default: "max-w-md"
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <!-- Darker backdrop with blur -->
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 bg-gray-900/80 backdrop-blur-sm transition-opacity duration-300"
        aria-hidden="true"
      />
      
    <!-- Modal container -->
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center p-4">
          <div class={"w-full #{@class}"}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="relative hidden rounded-lg bg-gray-800 p-6 shadow-2xl ring-1 ring-white/5 transition-all duration-300 ease-out"
              data-animate-in="opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
              data-animate-out="opacity-100 translate-y-0 sm:scale-100"
            >
              <!-- Close button -->
              <button
                phx-click={JS.exec("data-cancel", to: "##{@id}")}
                type="button"
                class="absolute right-4 top-4 text-gray-400 hover:text-white transition-colors"
                aria-label={gettext("close")}
              >
                <.icon name="hero-x-mark-solid" class="h-5 w-5 text-white" />
              </button>
              
    <!-- Content -->
              <div id={"#{@id}-content"} class="text-gray-100">
                {render_slot(@inner_block)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-hook="HideFlash"
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        {@title}
      </p>
      <p class="mt-2 text-sm leading-5">{msg}</p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title={gettext("Success!")} flash={@flash} />
      <.flash kind={:error} title={gettext("Error!")} flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error")}
        phx-connected={hide("#client-error")}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="space-y-8">
        {render_slot(@inner_block, f)}
        <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
          {render_slot(action, f)}
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a button with a sliding gradient animation effect.

  ## Examples
      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "bg-blue-700 hover:bg-blue-600 text-white",
        "group relative overflow-hidden rounded-lg py-2 px-3",
        "bg-black/20 hover:bg-black/40",
        "border border-white/10 hover:border-white/20",
        "transition-all duration-300 ease-out",
        "hover:-translate-y-0.5 hover:shadow-[0_0_15px_rgba(56,189,248,0.2)]",
        "font-semibold leading-6",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
      <span class="absolute inset-0 bg-gradient-to-r from-blue-500/10 to-transparent
        translate-x-[-100%] group-hover:translate-x-[100%]
        transition-transform duration-500">
      </span>
    </button>
    """
  end

  @doc """
  Renders a mini button, perfect for actions. Other than visual, pretty much the same as button.

  ## Examples

      <.mini_button>Send!</.mini_button>
      <.mini_button phx-click="go" class="ml-2">Send!</mini_button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def mini_button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 hover:bg-zinc-700 py-1 px-1",
        "text-sm font-semibold leading-6 text-white active:text-white/80",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :label_centered, :boolean, default: false
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week message_area)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :help_text, :string, default: nil, doc: "the help text for the input"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div phx-feedback-for={@name}>
      <label class="flex items-center gap-4 text-sm leading-6">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="rounded border-zinc-300 text-zinc-900 focus:ring-0"
          {@rest}
        />
        {@label}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}>{@label}</.label>
      <select
        id={@id}
        name={@name}
        class={[
          "mt-2 block w-full rounded-md border border-gray-300 bg-gray-800 text-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm [&>option]:bg-gray-800 [&>option]:text-white",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <p class="mt-2 text-sm text-white/70">{@help_text}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
          "min-h-[6rem] phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "message_area"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} class="py-4">
      <div class="flex flex-col gap-2">
        <%= if @label do %>
          <label
            for={@id}
            class={[
              "flex font-semibold underline",
              @label_centered && "flex justify-center mb-4",
              @label_centered || "mt-4"
            ]}
          >
            {@label}&nbsp;<%= if @label_centered == false do %>
              <.icon name="hero-arrow-turn-right-down" class="mt-2 ml-2 w-6 h-6" />
            <% end %>
          </label>
        <% end %>
        <input
          type={@type}
          name={@name}
          id={@id}
          placeholder={assigns[:placeholder]}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          autocomplete="off"
          class={
            [
              "mt-2 block w-full focus:ring-0 sm:text-xl sm:leading-6 pb-2 bg-transparent",
              "border-b-2 border-white text-center outline-none placeholder:text-white/40"
              # "phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400,
              # @errors == [] && "border-zinc-300 focus:border-zinc-400",
              # @errors != [] && "border-rose-400 focus:border-rose-400"
            ]
          }
          {@rest}
        />
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
          "phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600 phx-no-feedback:hidden">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", @class]}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-white">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-white">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="w-[40rem] mt-11 sm:w-full">
        <thead class="text-sm text-left leading-6 text-zinc-500">
          <tr>
            <th :for={col <- @col} class="p-0 pb-4 pr-6 font-normal">{col[:label]}</th>
            <th :if={@action != []} class="relative p-0 pb-4">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="relative divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700"
        >
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="group hover:bg-zinc-50">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["relative p-0", @row_click && "hover:cursor-pointer"]}
            >
              <div class="block py-4 pr-6">
                <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-zinc-50 sm:rounded-l-xl" />
                <span class={["relative", i == 0 && "font-semibold text-zinc-900"]}>
                  {render_slot(col, @row_item.(row))}
                </span>
              </div>
            </td>
            <td :if={@action != []} class="relative w-14 p-0">
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-zinc-50 sm:rounded-r-xl" />
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
                >
                  {render_slot(action, @row_item.(row))}
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title"><%= @post.title %></:item>
        <:item title="Views"><%= @post.views %></:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="mt-14">
      <dl class="-my-4 divide-y divide-zinc-100">
        <div :for={item <- @item} class="flex gap-4 py-4 text-sm leading-6 sm:gap-8">
          <dt class="w-1/4 flex-none text-zinc-500">{item.title}</dt>
          <dd class="text-zinc-700">{render_slot(item)}</dd>
        </div>
      </dl>
    </div>
    """
  end

  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="flex">
      <.link
        navigate={@navigate}
        class="group relative overflow-hidden rounded-lg px-4 py-2
          bg-black/20 hover:bg-black/40
          border border-white/10 hover:border-white/20
          transition-all duration-300 ease-out
          hover:-translate-y-0.5 hover:shadow-[0_0_15px_rgba(56,189,248,0.2)]
          flex items-center gap-2 text-sm font-semibold text-white/90"
      >
        <.icon
          name="hero-arrow-left-solid"
          class="h-4 w-4 text-blue-400 group-hover:text-yellow-400 transition-colors duration-300"
        />
        {render_slot(@inner_block)}
        <span class="absolute inset-0 bg-gradient-to-r from-blue-500/10 to-transparent
          translate-x-[-100%] group-hover:translate-x-[100%]
          transition-transform duration-500">
        </span>
      </.link>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(StormfulWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(StormfulWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  def basic_lightning_svg(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 20" className="w-full h-4">
      <defs>
        <filter id="glow">
          <feGaussianBlur stdDeviation="1.5" result="coloredBlur" />
          <feMerge>
            <feMergeNode in="coloredBlur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>
      <path
        d="M0,10 L10,3 L20,17 L30,7 L40,13 L50,3 L60,17 L70,7 L80,13 L90,3 L100,17
             L110,7 L120,13 L130,3 L140,17 L150,7 L160,13 L170,3 L180,17 L190,7 L200,10"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        filter="url(#glow)"
      />
      <path
        d="M0,10 L7,5 L14,15 L21,8 L28,12 L35,5 L42,15 L49,8 L56,12 L63,5 L70,15
             L77,8 L84,12 L91,5 L98,15 L105,8 L112,12 L119,5 L126,15 L133,8 L140,12
             L147,5 L154,15 L161,8 L168,12 L175,5 L182,15 L189,8 L196,12 L200,10"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
        opacity="0.6"
      />
    </svg>
    """
  end

  def animated_lightning_svg(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 30" class="w-[470px] h-8">
      <defs>
        <linearGradient id="electric-gradient" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stop-color="#60A5FA" />
          <stop offset="50%" stop-color="#FACC15" />
          <stop offset="100%" stop-color="#60A5FA" />
          <animate attributeName="x1" values="0%;100%;0%" dur="6s" repeatCount="indefinite" />
          <animate attributeName="x2" values="100%;200%;100%" dur="6s" repeatCount="indefinite" />
        </linearGradient>
      </defs>
      <g>
        <path
          d="M0,15 L10,10 L20,20 L30,5 L40,25 L50,12 L60,22 L70,7 L80,17 L90,2 L100,27
         L110,15 L120,25 L130,5 L140,20 L150,10 L160,30 L170,0 L180,22 L190,12 L200,15"
          fill="none"
          stroke="currentColor"
          stroke-width="2.5"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="text-blue-400"
        >
          <animate
            attributeName="d"
            dur="0.8s"
            repeatCount="indefinite"
            values="
          M0,15 L10,10 L20,20 L30,5 L40,25 L50,12 L60,22 L70,7 L80,17 L90,2 L100,27 L110,15 L120,25 L130,5 L140,20 L150,10 L160,30 L170,0 L180,22 L190,12 L200,15;
          M0,15 L10,25 L20,5 L30,20 L40,10 L50,27 L60,2 L70,22 L80,7 L90,17 L100,12 L110,30 L120,0 L130,25 L140,15 L150,5 L160,20 L170,10 L180,27 L190,17 L200,15;
          M0,15 L10,20 L20,10 L30,25 L40,5 L50,22 L60,12 L70,27 L80,2 L90,17 L100,7 L110,20 L120,15 L130,30 L140,0 L150,25 L160,10 L170,20 L180,12 L190,22 L200,15;
          M0,15 L10,10 L20,20 L30,5 L40,25 L50,12 L60,22 L70,7 L80,17 L90,2 L100,27 L110,15 L120,25 L130,5 L140,20 L150,10 L160,30 L170,0 L180,22 L190,12 L200,15"
          />
        </path>
        <path
          d="M0,15 L7,12 L14,17 L21,7 L28,22 L35,10 L42,20 L49,5 L56,25 L63,15 L70,27
         L77,2 L84,17 L91,12 L98,22 L105,7 L112,20 L119,10 L126,25 L133,5 L140,15
         L147,30 L154,0 L161,20 L168,10 L175,25 L182,15 L189,5 L196,22 L200,15"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="text-yellow-400"
        >
          <animate
            attributeName="d"
            dur="0.6s"
            repeatCount="indefinite"
            values="
          M0,15 L7,12 L14,17 L21,7 L28,22 L35,10 L42,20 L49,5 L56,25 L63,15 L70,27 L77,2 L84,17 L91,12 L98,22 L105,7 L112,20 L119,10 L126,25 L133,5 L140,15 L147,30 L154,0 L161,20 L168,10 L175,25 L182,15 L189,5 L196,22 L200,15;
          M0,15 L7,22 L14,7 L21,17 L28,12 L35,25 L42,5 L49,20 L56,10 L63,27 L70,2 L77,17 L84,12 L91,22 L98,7 L105,20 L112,15 L119,30 L126,0 L133,25 L140,10 L147,20 L154,15 L161,5 L168,25 L175,12 L182,22 L189,17 L196,7 L200,15;
          M0,15 L7,17 L14,12 L21,22 L28,7 L35,20 L42,10 L49,25 L56,5 L63,17 L70,12 L77,27 L84,2 L91,20 L98,15 L105,30 L112,0 L119,22 L126,7 L133,17 L140,12 L147,25 L154,10 L161,15 L168,20 L175,5 L182,27 L189,12 L196,17 L200,15;
          M0,15 L7,12 L14,17 L21,7 L28,22 L35,10 L42,20 L49,5 L56,25 L63,15 L70,27 L77,2 L84,17 L91,12 L98,22 L105,7 L112,20 L119,10 L126,25 L133,5 L140,15 L147,30 L154,0 L161,20 L168,10 L175,25 L182,15 L189,5 L196,22 L200,15"
          />
        </path>
      </g>
    </svg>
    """
  end

  attr :big_name, :string
  attr :little_name, :string
  attr :link, :string, required: false

  def cool_header(assigns) do
    ~H"""
    <div class="flex flex-col items-center space-y-2 py-3">
      <!-- Little name with subtle pulse -->
      <%= if assigns[:little_name]  do %>
        <p class="text-base font-bold text-zinc-300 animate-[pulse_4s_ease-in-out_infinite]">
          {@little_name}
        </p>
      <% end %>
      <span class="flex gap-2 items-center">
        <!-- Big name with clean lightning effect -->
        <h2 class="relative text-3xl font-bold">
          <!-- Single smooth underline -->
          <span class="absolute bottom-0 left-0 h-px w-full bg-gradient-to-r from-blue-400 via-yellow-300 to-blue-400 opacity-70
          animate-[shine_6s_linear_infinite]">
          </span>
          <!-- Clean text -->
          <span class="relative text-white">
            {@big_name}
          </span>
        </h2>
        <%= if assigns[:link]  do %>
          <span>
            &nbsp; <a href={assigns.link}><.icon name="hero-link" class="h-6 w-6" /></a>
          </span>
        <% end %>
      </span>
    </div>

    <style type="text/css">
      @keyframes shine {
        0%, 100% { background-position: -100% center; }
        50% { background-position: 100% center; }
      }
    </style>
    """
  end
end
