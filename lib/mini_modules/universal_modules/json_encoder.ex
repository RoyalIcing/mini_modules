defmodule MiniModules.UniversalModules.JSONEncoder do
  defp encode({:export, {:const, name, value}})
       when is_binary(value) or is_number(value) or is_list(value) or is_nil(value),
       do: [{name, value}]

  defp encode({:export, {:const, name, {:set, members}}}),
    do: [{name, MapSet.to_list(MapSet.new(members))}] # TODO: preserve order

  defp encode(_), do: []

  def to_json(module_body) do
    Map.new(for statement <- module_body, json <- encode(statement), do: json)
  end
end
