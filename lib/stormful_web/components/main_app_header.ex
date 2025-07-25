defmodule StormfulWeb.MainAppHeader do
  @moduledoc false

  use StormfulWeb, :html

  attr :current_user, :any, required: true

  def main_app_header(assigns) do
    ~H"""
    <header class="bg-black/20 backdrop-blur-sm border-b border-white/10">
      <div class="mx-auto px-3 py-3 sm:px-4 sm:py-4">
        <!-- Mobile layout: stacked -->
        <div class="flex flex-col gap-3 sm:hidden">
          <!-- Top row: Brand and user menu -->
          <div class="flex items-center justify-between">
            <!-- Stormful Brand -->
            <span class="text-xl font-bold">
              <.link
                navigate={~p"/journal"}
                class="text-blue-400 hover:text-yellow-400 transition-colors duration-300"
              >
                Stormful
              </.link>
            </span>
            
    <!-- User menu - mobile -->
            <%= if @current_user do %>
              <div class="flex items-center gap-2">
                <.link
                  href={~p"/users/settings"}
                  class="p-2 rounded-lg bg-black/20 hover:bg-black/40 border border-white/10
                         transition-all duration-300 flex items-center justify-center"
                >
                  <.icon name="hero-cog-6-tooth" class="w-5 h-5 text-blue-400" />
                </.link>

                <.link
                  href={~p"/users/log_out"}
                  method="delete"
                  class="p-2 rounded-lg bg-black/20 hover:bg-black/40 border border-white/10
                         transition-all duration-300 flex items-center justify-center"
                >
                  <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5 text-yellow-400" />
                </.link>
              </div>
            <% end %>
          </div>
          
    <!-- Bottom row: Navigation - mobile -->
          <%= if @current_user do %>
            <nav class="flex gap-2">
              <.link
                navigate={~p"/journal"}
                class="flex-1 flex items-center justify-center gap-2 py-2.5 px-3 rounded-lg
                       bg-indigo-600/20 border border-indigo-400/20 text-white/90 font-medium text-sm
                       transition-all duration-300"
              >
                <.icon name="hero-book-open" class="w-4 h-4 text-indigo-300" /> Journal
              </.link>

              <.link
                navigate={~p"/into-the-storm"}
                class="flex-1 flex items-center justify-center gap-2 py-2.5 px-3 rounded-lg
                       bg-purple-600/20 border border-purple-400/20 text-white/90 font-medium text-sm
                       transition-all duration-300"
              >
                <.icon name="hero-bolt" class="w-4 h-4 text-purple-300" /> Sensicality Center
              </.link>

              <.link
                navigate={~p"/agenda"}
                class="flex-1 flex items-center justify-center gap-2 py-2.5 px-3 rounded-lg
                       bg-red-600/20 border border-red-400/20 text-white/90 font-medium text-sm
                       transition-all duration-300"
              >
                <.icon name="hero-calendar" class="w-4 h-4 text-red-300" /> Agenda
              </.link>
            </nav>
          <% end %>
        </div>
        
    <!-- Desktop layout: horizontal -->
        <div class="hidden sm:flex items-center justify-between">
          <!-- Left side: Brand + Navigation -->
          <div class="flex items-center gap-6">
            <!-- Stormful Brand -->
            <span class="text-2xl font-bold">
              <.link
                navigate={~p"/journal"}
                class="text-blue-400 hover:text-yellow-400 transition-colors duration-300"
              >
                Stormful
              </.link>
            </span>
            
    <!-- Main Navigation -->
            <%= if @current_user do %>
              <nav class="flex items-center gap-3">
                <.link
                  navigate={~p"/journal"}
                  class="group relative overflow-hidden rounded-lg px-3 py-1.5
                         bg-blue-600/20 hover:bg-blue-500/30
                         border border-blue-400/20 hover:border-blue-300/40
                         transition-all duration-300 ease-out
                         flex items-center gap-2 text-sm font-medium text-white/90"
                >
                  <.icon name="hero-book-open" class="w-4 h-4 text-blue-300" /> Journal
                </.link>

                <.link
                  navigate={~p"/into-the-storm"}
                  class="group relative overflow-hidden rounded-lg px-3 py-1.5
                         bg-purple-600/20 hover:bg-purple-500/30
                         border border-purple-400/20 hover:border-purple-300/40
                         transition-all duration-300 ease-out
                         flex items-center gap-2 text-sm font-medium text-white/90"
                >
                  <.icon name="hero-bolt" class="w-4 h-4 text-purple-300" /> Sensicality Center
                </.link>

                <.link
                  navigate={~p"/agenda"}
                  class="group relative overflow-hidden rounded-lg px-3 py-1.5
                         bg-red-600/20 hover:bg-red-500/30
                         border border-red-400/20 hover:border-red-300/40
                         transition-all duration-300 ease-out
                         flex items-center gap-2 text-sm font-medium text-white/90"
                >
                  <.icon name="hero-calendar" class="w-4 h-4 text-red-300" /> Agenda
                </.link>
              </nav>
            <% end %>
          </div>
          
    <!-- Right side: User menu -->
          <%= if @current_user do %>
            <div class="flex items-center gap-3">
              <.link
                href={~p"/users/settings"}
                class="group relative overflow-hidden rounded-lg px-3 py-1.5 text-sm font-semibold text-white/90
                       bg-black/20 hover:bg-black/40 border border-white/10 hover:border-white/20
                       transition-all duration-300 ease-out hover:-translate-y-0.5 hover:shadow-[0_0_15px_rgba(56,189,248,0.2)]
                       flex items-center gap-2"
              >
                <.icon
                  name="hero-cog-6-tooth"
                  class="w-4 h-4 text-blue-400 group-hover:text-yellow-400 transition-colors duration-300"
                />
              </.link>

              <.link
                href={~p"/users/log_out"}
                method="delete"
                class="group relative overflow-hidden rounded-lg px-3 py-1.5 text-sm font-semibold text-white/90
                       bg-black/20 hover:bg-black/40 border border-white/10 hover:border-white/20
                       transition-all duration-300 ease-out hover:-translate-y-0.5 hover:shadow-[0_0_15px_rgba(234,179,8,0.2)]
                       flex items-center gap-2"
              >
                <.icon
                  name="hero-arrow-right-on-rectangle"
                  class="w-4 h-4 text-yellow-400 group-hover:text-blue-400 transition-colors duration-300"
                />
              </.link>
            </div>
          <% end %>
        </div>
      </div>
    </header>
    """
  end
end
