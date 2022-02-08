defmodule MiniModulesWeb.EditorLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}

  alias MiniModules.UniversalModules
  # alias MiniModules.UniversalModules.Parser, as: Parser

  # on_mount {LiveBeatsWeb.UserAuth, :current_user}

  def render(assigns) do
    ~H"""
    <.form
      for={:editor}
      id="editor-form"
      class="space-y-8"
      phx-change="changed">
      <textarea name="input" rows={10} class="w-full text-black"><%= @input %></textarea>
    </.form>

    <%= if @error_message do %>
    <div role="alert" class="p-4 text-red-300">
      <%= @error_message %>
    </div>
    <% end %>

    <section>
      <output class="block"><%= @result %></output>
    </section>
    """
  end

  defp process(input) do
    decoded = try do
      UniversalModules.Parser.decode(input)
    rescue
      _ -> {:error, :rescue}
    catch
      _ -> {:error, :catch}
    end
    # decoded = UniversalModules.Parser.decode(input)
    # identifiers = UniversalModules.Inspector.list_identifiers(elem(decoded, 1))
    {json, error_message} = case decoded do
      {:ok, elements} -> {UniversalModules.JSONEncoder.to_json(elements), nil}
      {:error, reason} -> {nil, inspect(reason)}
    end

    %{input: input, result: Jason.encode!(json, pretty: true), error_message: error_message}
  end

  def mount(_parmas, _session, socket) do
    {:ok, assign(socket, process("""
export const a = 5;
export const exampleDotOrg = new URL("https://example.org");
"""
))}
  end

  def handle_event("changed", %{"input" => input}, socket) do
    {:noreply, assign(socket, process(input))}
  end
end
