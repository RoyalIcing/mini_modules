defmodule MiniModulesWeb.Input.CodeEditorComponent do
  use MiniModulesWeb, :component

  def monaco(assigns) do
    ~H"""
    <minimodules-monaco-editor id={@id} source={@input} style="display: block; width: 900px; height: 400px;" phx-hook="WebComponent" name={@name} phx-update="ignore">
      <!--<textarea name="input" rows={16} class="w-full font-mono bg-gray-800 text-white border border-gray-600"><%= @input %></textarea>-->
    </minimodules-monaco-editor>
    """
  end
end
