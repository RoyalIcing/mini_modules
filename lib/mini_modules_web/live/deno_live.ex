defmodule MiniModulesWeb.DenoLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:add_result, "")
      |> assign(:js_result, nil)
      |> assign(:js_execution_ms, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <article class="py-16 px-4 prose lg:prose-xl mx-auto">
      <h1 class="text-center">Deno</h1>

      <form phx-change="js">
        <label class="block">
          <div>JavaScript Source</div>
          <textarea name="source" rows="10" class="w-full border" placeholder="Enter your JavaScript masterpiece…"></textarea>
        </label>
        <output class="block bg-green-100">
          <pre class="empty:hidden p-2 text-black"><%= @js_result %></pre>
          <div class="empty:hidden"><%= if @js_execution_ms, do: "#{@js_execution_ms}ms", else: "" %></div>
        </output>
        <button class="mt-2 px-4 py-2 text-xl text-white bg-blue-600 border border-blue-700 rounded">Execute JavaScript</button>
      </form>
    </article>
    """
  end

  @impl true
  def handle_event("add", %{"first" => first, "second" => second}, socket) do
    {first, _} = Integer.parse(first)
    {second, _} = Integer.parse(second)

    result = Molten.add(first, second)

    socket = socket |> assign(:add_result, result)
    {:noreply, socket}
  end

  def handle_event("js", %{"source" => source}, socket) do
    start_ms = System.monotonic_time(:millisecond)

    # TODO: handle infinite loops
      # Molten.js(source)
      task = Task.async(fn () ->
        try do
          Molten.js(source)
        rescue
          ErlangError -> :error
        end
      end)
      timeout = 1000
      result = case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
        {:ok, result} ->
          result

        {:exit, reason} ->
          reason

        nil ->
          Logger.warn("Failed to get a result in #{timeout}ms")
          nil
      end

    # task = Task.async(fn -> Molten.js(source) end)

    end_ms = System.monotonic_time(:millisecond)
    js_execution_ms = end_ms - start_ms

    socket = socket |> assign(:js_result, result) |> assign(:js_execution_ms, js_execution_ms)
    {:noreply, socket}
  end
end
