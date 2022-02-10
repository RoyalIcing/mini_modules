defmodule MiniModulesWeb.YieldMachineLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}

  alias MiniModules.UniversalModules

  # on_mount {LiveBeatsWeb.UserAuth, :current_user}

  def render(assigns) do
    ~H"""
    <.form
      for={:editor}
      id="editor-form"
      class="flex gap-4"
      phx-change="changed">
      <textarea name="source" rows={16} class="w-full font-mono bg-gray-800 text-white border border-gray-600"><%= @source %></textarea>

      <section class="block w-1/2 space-y-4">
        <textarea name="event_lines" rows={10} class="w-full font-mono bg-gray-800 text-white border border-gray-600"><%= @event_lines %></textarea>
        <%= if @error_message do %>
          <div role="alert" class="text-red-300">
            <%= @error_message %>
          </div>
        <% end %>
        <%= if @state do %>
          <output class="block text-center">Currently <%= @state %></output>
        <% end %>
        <mermaid-image source={render_mermaid(@state, @components)} class="block bg-white text-center">
        </mermaid-image>
      </section>
    </.form>

    """
  end

  defp render_mermaid(state, components) do
    """
    graph TB
    #{for {from, event, to} <- components, do: "#{from}-->|#{event}|#{to}\n"}
    style #{state} fill:#222,color:#ffde00
    """
  end

  defp process(source, event_lines) do
    decoded =
      try do
        UniversalModules.Parser.decode(source)
      rescue
        _ -> {:error, :invalid_module}
      catch
        _ -> {:error, :catch}
      end

    events = String.split(event_lines, [" ", "\n", "\r"], trim: true)

    {state, components, error_message} =
      case decoded do
        {:ok, elements} ->
          case UniversalModules.YieldMachine.interpret_machine(elements, events) do
            {:ok, %{current: state, components: components}} ->
              {state, components, nil}

            {:error, reason} ->
              {nil, nil, inspect(reason)}
          end

        {:error, reason} ->
          {nil, nil, inspect(reason)}
      end

    %{
      source: source,
      state: state,
      event_lines: event_lines,
      error_message: error_message,
      components: components
    }
  end

  def mount(_parmas, _session, socket) do
    {:ok,
     assign(
       socket,
       process(~S"""
       export function Switch() {
        function* OFF() {
          yield on("FLICK", ON);
        }
        function* ON() {
          yield on("FLICK", OFF);
        }

        return OFF;
       }
       """, "FLICK\nFLICK\nFLICK")
     )}
  end

  def handle_event("changed", %{"source" => source, "event_lines" => event_lines}, socket) do
    {:noreply, assign(socket, process(source, event_lines))}
  end
end
