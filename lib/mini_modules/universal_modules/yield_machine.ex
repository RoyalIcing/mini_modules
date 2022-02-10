defmodule MiniModules.UniversalModules.YieldMachine do
  defmodule Context do
    defstruct components: %{}, constants: %{}

    def from_module(module_body) do
      components =
        Map.new(for statement <- module_body, result <- from_statement(statement), do: result)

      %Context{components: components}
    end

    defp from_statement({:generator_function, name, _args, _body} = statement),
      do: [{name, statement}]

    defp from_statement(_), do: []

    def register_component(%Context{} = context, identifier, component) do
      put_in(context.components[identifier], component)
    end
  end

  def interpret_machine(module_body) do
    context = Context.from_module(module_body)

    results = for statement <- module_body, result <- run(statement, context), do: result

    case results do
      [result] -> result
      [] -> {:error, :expected_exported_function}
      results -> {:error, {:too_many_exports, results}}
    end
  end

  defp run({:export, {:generator_function, _name, _args, body}}, context) do
    [evaluate(body, context)]
  end

  defp run({:export, {:function, _name, _args, body}}, context) do
    [evaluate(body, context)]
  end

  defp run(_, _), do: []

  defp evaluate([{:comment, _} | statements], context), do: evaluate(statements, context)

  defp evaluate([{:generator_function, name, _args, _body} = component | statements], context) do
    context = context |> Context.register_component(name, component)
    evaluate(statements, context)
  end

  defp evaluate([{:yield, {:call, {:ref, "on"}, args}} | statements], context) do
    nil
  end

  defp evaluate(
         [{:const, identifier, {:yield, {:ref, component_name}}} | statements],
         %Context{components: components} = context
       )
       when is_map_key(components, component_name) do
    {:generator_function, _name, _args, body} = components[component_name]

    case evaluate(body, context) do
      {:ok, value} ->
        evaluate(statements, %Context{
          context
          | constants: Map.put(context.constants, identifier, value)
        })

      {:error, _reason} = tuple ->
        tuple
    end
  end

  # defp evaluate([{:const, [identifier], {:yield, yielded}} | statements], rest, _context)
  #      when is_binary(identifier) do
  #   {:error, {:did_not_match, identifier, %{rest: rest}}}
  # end

  defp evaluate([{:return, value}], context) do
    return(value, context)
  end

  defp evaluate([], _context) do
    {:error, :expected_return}
  end

  defp return({:ref, identifier}, context) do
    # actual_value = Map.get(context.constants, identifier)
    {:ok, %{state: identifier}}
  end

  defp return(value, _context) do
    {:error, :invalid_return_value}
  end
end
