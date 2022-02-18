defmodule MiniModulesWeb.EditorLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}

  alias MiniModules.UniversalModules
  alias MiniModules.Fetch
  # alias MiniModules.UniversalModules.Parser, as: Parser

  # on_mount {LiveBeatsWeb.UserAuth, :current_user}

  def mount(_parmas, _session, socket) do
    socket =
      socket
      |> assign(
        process("""
        import { pi } from "https://gist.githubusercontent.com/BurntCaramel/d9d2ca7ed6f056632696709a2ae3c413/raw/0234322cf854d52e2f2bd33aa37e8c8b00f9df0a/1.js";
        import { Loader } from "https://gist.githubusercontent.com/BurntCaramel/21dbd15652c8d9a7570f49fba8bda701/raw";
        export { pi };
        export { Loader };
        export const a = 5;
        export const exampleDotOrg = new URL("https://example.org");
        """)
      )

    # responses =
    #   MiniModules.Fetch.BulkSerial.new([
    #     "https://gist.githubusercontent.com/BurntCaramel/21dbd15652c8d9a7570f49fba8bda701/raw"
    #   ])
    # IO.inspect(responses)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.form
      for={:editor}
      id="editor-form"
      class="flex gap-4"
      phx-change="changed"
      phx-submit="load"
    >
      <textarea name="input" rows={16} class="w-full font-mono bg-gray-800 text-white border border-gray-600"><%= @input %></textarea>


      <section class="block w-1/2 space-y-4">
        <button type="submit" value="load">Load</button>

        <%= if @error_message do %>
        <div role="alert" class="p-4 text-red-300">
          <%= @error_message %>
        </div>
        <% end %>

        <%= if @result do %>
          <output class="block p-4 bg-green-900/25 text-white border border-green-800"><pre><%= inspect(@result.module, pretty: true) %></pre></output>
          <output class="block p-4 bg-green-900/25 text-white border border-green-800"><%= @result.json %></output>
        <% end %>
      </section>
    </.form>

    """
  end

  defp process(input, load \\ false) do
    decoded =
      try do
        UniversalModules.Parser.decode(input)
      rescue
        _ -> {:error, :rescue}
      catch
        _ -> {:error, :catch}
      end

    decoded =
      case {load, decoded} do
        {true, {:ok, module}} ->
          UniversalModules.ImportResolver.transform(module, fn url ->
            # TODO: add caching
            %{done: true, data: data} = Fetch.Get.load(url)
            # Process.sleep(1000)
            UniversalModules.Parser.decode(data)
            # {:ok, [
            #   {:export, {:const, "b", 6}}
            # ]}
          end)

        _ ->
          decoded
      end

    # decoded = UniversalModules.Parser.decode(input)
    # identifiers = UniversalModules.Inspector.list_identifiers(elem(decoded, 1))
    {result, error_message} =
      case decoded do
        {:ok, module} ->
          {%{
             module: module,
             json: UniversalModules.JSONEncoder.to_json(module) |> Jason.encode!(pretty: true)
           }, nil}

        {:error, reason} ->
          {nil, inspect(reason)}
      end

    %{input: input, result: result, error_message: error_message}
  end

  def handle_event("changed", %{"input" => input}, socket) do
    {:noreply, assign(socket, process(input))}
  end

  def handle_event("load", %{"input" => input}, socket) do
    {:noreply, assign(socket, process(input, true))}
  end
end
