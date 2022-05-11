defmodule MiniModulesWeb.Input.CodeEditorComponent do
  use MiniModulesWeb, :component

  def monaco(assigns) do
    assigns = Map.merge(%{change_clock: 0, language: "javascript"}, assigns)

    ~H"""
    <minimodules-monaco-editor
      id={@id}
      change-clock={@change_clock}
      language={@language}
      source={@input}
      name={@name}
      style="display: block; width: 900px; height: 400px;"
      phx-hook="WebComponent"
      phx-update="ignore">
      <!--<textarea name="input" rows={16} class="w-full font-mono bg-gray-800 text-white border border-gray-600"><%= @input %></textarea>-->
    </minimodules-monaco-editor>
    """
  end
end
