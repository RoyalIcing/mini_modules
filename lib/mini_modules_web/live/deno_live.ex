defmodule MiniModulesWeb.DenoLive do
  use MiniModulesWeb, {:live_view, container: {:div, []}}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:add_result, "")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <article class="py-16 px-4 prose lg:prose-xl mx-auto text-center">
      <h1>Deno</h1>

      <form phx-submit="add">
        <label>First <input name="first"></label>
        <label>Second <input name="second"></label>
        <output><%= @add_result %></output>
        <button class="px-4 py-2 text-xl text-white bg-blue-600 border border-blue-700 rounded">Add</button>
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
end
