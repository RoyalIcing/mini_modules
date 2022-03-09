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
        import { YouTubeURL } from "https://gist.github.com/BurntCaramel/5cabb793e7e4ba961c00a807323e0afe/raw";
        export { YouTubeURL };
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
      <minimodules-monaco-editor id="monaco-editor" source={@input} style="display: block; width: 900px; height: 400px;" phx-hook="WebComponent" name="input" phx-update="ignore">
        <!--<textarea name="input" rows={16} class="w-full font-mono bg-gray-800 text-white border border-gray-600"><%= @input %></textarea>-->
      </minimodules-monaco-editor>
      <!--<textarea name="input" rows={16} class="w-full font-mono bg-gray-800 text-white border border-gray-600"><%= @input %></textarea>-->

      <section class="block w-1/2 space-y-4">
        <button type="submit" value="load">Load</button>

        <%= if @error_message do %>
        <div role="alert" class="p-4 bg-red-900/20 text-red-800 border border-red-800/25">
          <pre><%= @error_message %></pre>
        </div>
        <% end %>

        <%= if @result do %>
          <output class="block p-4 bg-green-900/20 text-green-900 border border-green-800"><pre><%= inspect(@result.module, pretty: true) %></pre></output>
          <output class="block p-4 bg-green-900/20 text-green-900 border border-green-800"><%= @result.json %></output>
        <% end %>
      </section>
    </.form>

    """
  end

  defp process(input, load \\ nil) do
    decoded =
      try do
        UniversalModules.Parser.decode(input)
      rescue
        _ -> {:error, :rescue}
      catch
        _ -> {:error, :catch}
      end

    decoded =
      case decoded do
        {:ok, module} ->
          {:ok, module, %{imported_modules: _imported_modules}} =
            resolve_imports(load, module, %{})
            {:ok, module}

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
          {nil, inspect(reason, pretty: true)}
      end

    %{input: input, result: result, error_message: error_message}
  end

  defp resolve_imports(action, module, previously_imported_modules) do
    UniversalModules.ImportResolver.transform(module, fn url ->
      case {previously_imported_modules, action} do
        # Use previously loaded module.
        {%{^url => loaded_module}, _} ->
          {:ok, loaded_module}

        # Otherwise, load if we are being asked to.
        {_, :load} ->
          case Fetch.Get.load(url) do
            %{done: true, data: data} ->
              UniversalModules.Parser.decode(data)

            response ->
              {:error, {:did_not_load, response}}
          end

        # Otherwise, returning nothing.
        {_, _} ->
          {:ok, nil}
      end
    end)
  end

  def handle_event("changed", %{"input" => input}, socket) do
    IO.puts("CHANGE! #{input}")
    {:noreply, assign(socket, process(input))}
  end

  def handle_event("load", %{"input" => input}, socket) do
    {:noreply, assign(socket, process(input, :load))}
  end
end
