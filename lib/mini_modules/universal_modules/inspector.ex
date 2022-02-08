defmodule MiniModules.UniversalModules.Inspector do
  defp is_identifier({:const, _, _}), do: true
  defp is_identifier({:function, _, _, _}), do: true
  defp is_identifier({:generator_function, _, _, _}), do: true
  defp is_identifier(_), do: false

  def list_identifiers(module_body) do
    for statement <- module_body, is_identifier(statement), do: statement
  end
end
