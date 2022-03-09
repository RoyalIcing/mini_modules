defmodule MiniModules.UniversalModules.JSONEncoder do
  alias MiniModules.UniversalModules.Lookup

  def to_json(module_body) do
    locals =
      Map.new(
        for statement <- module_body,
            result = Lookup.pair(statement),
            result != nil,
            {name, value} = result,
            do: {name, value}
      )

    Map.new(for statement <- module_body, json <- encode(statement, locals), do: json)
  end

  defp fragment_to_string(fragment, _locals) when is_binary(fragment), do: fragment

  defp fragment_to_string({:url, url_string}, _locals) when is_binary(url_string), do: url_string

  defp fragment_to_string({:url, [relative: relative, base: base]}, locals) do
    case fragment_to_string(base, locals) do
      nil ->
        nil

      s ->
        URI.merge(URI.parse(s), relative) |> to_string()
    end
  end

  defp fragment_to_string({:ref, ref}, locals) when is_map_key(locals, ref) do
    fragment_to_string(locals[ref], locals)
  end

  defp fragment_to_string(_, _locals), do: nil

  defp encode({:export, {:const, name, value}}, _locals)
       when is_binary(value) or
              is_number(value) or
              is_boolean(value) or
              is_list(value) or
              is_nil(value),
       do: [{name, value}]

  defp encode({:export, {:const, name, {:set, members}}}, _locals),
    do: [{name, Enum.uniq(members)}]

  defp encode({:export, {:const, name, {:url, _} = url}}, locals) do
    value = fragment_to_string(url, locals)
    [{name, value}]
  end

  defp encode(_, _), do: []
end
