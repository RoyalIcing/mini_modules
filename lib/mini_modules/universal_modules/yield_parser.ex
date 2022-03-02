defmodule MiniModules.UniversalModules.YieldParser do
  defmodule Context do
    defstruct reply: nil, components: %{}, constants: %{}

    def from_module(module_body) do
      components =
        Map.new(for statement <- module_body, result <- from_statement(statement), do: result)

      %Context{components: components}
    end

    defp from_statement({:generator_function, name, _args, _body} = statement),
      do: [{name, statement}]

    defp from_statement(_), do: []

    def assign_constant(%Context{} = context, identifier, value) do
      put_in(context.constants[identifier], value)
    end
  end

  def run_parser(module_body, input) do
    context = Context.from_module(module_body)

    results = for statement <- module_body, result <- run(statement, input, context), do: result

    case results do
      [result] -> result
      [] -> {:error, :expected_exported_generator_function}
      results -> {:error, {:too_many_exported_generator_functions, results}}
    end
  end

  defp run({:export, {:generator_function, _name, _args, body}}, input, context) do
    [evaluate(body, input, context)]
  end

  defp run(_, _, _), do: []

  defp regex(source, rest) do
    case Regex.compile(source) do
      {:ok, regex} ->
        case Regex.split(regex, rest, parts: 2, include_captures: true) do
          ["", matched, rest] -> {:ok, matched, rest}
          _ -> {:error, {:did_not_match, {:regex, source}, %{rest: rest}}}
        end

      {:error, reason} ->
        {:error, {:invalid_regex, source, reason}}
    end
  end

  defp evaluate([{:comment, _} | statements], rest, context),
    do: evaluate(statements, rest, context)

  defp evaluate([{:yield, value} | statements], rest, context) when is_binary(value) do
    size = byte_size(value)

    case rest do
      <<prefix::size(size)-binary, rest::bitstring>> when prefix == value ->
        evaluate(statements, rest, context)

      _ ->
        {:error, {:did_not_match, value, %{rest: rest}}}
    end
  end

  defp evaluate([{:yield, {:ref, "mustEnd"}} | statements], rest, context) do
    case rest do
      "" ->
        evaluate(statements, rest, context)

      rest ->
        {:error, {:expected_eof, %{rest: rest}}}
    end
  end

  # defp evaluate([{:yield, {:regex, source}} | statements], rest, context) do
  #   case Regex.compile(source) do
  #     {:ok, regex} ->
  #       ["", matched, rest] = Regex.split(regex, rest, parts: 2, include_captures: true)
  #       evaluate(statements, rest, %Context{context | reply: matched})

  #     {:error, reason} ->
  #       {:error, {:invalid_regex, source, reason, %{rest: rest}}}
  #   end
  # end

  defp evaluate([{:yield, choices} | statements], rest, context) when is_list(choices) do
    Enum.reduce_while(choices, {:error, :no_choices}, fn choice, _fallback ->
      case evaluate([{:yield, choice} | statements], rest, context) do
        success = {:ok, _, _} ->
          {:halt, success}

        {:error, {:did_not_match, _, _}} ->
          {:cont, {:error, {:no_matching_choice, choices, %{rest: rest}}}}
      end
    end)
  end

  defp evaluate([{:yield, value} | _statements], rest, _context) do
    {:error, {:did_not_match, value, %{rest: rest}}}
  end

  defp evaluate(
         [{:const, [identifier], {:yield, {:regex, regex_source}}} | statements],
         rest,
         context
       )
       when is_binary(identifier) do
    with {:ok, match, rest} <- regex(regex_source, rest) do
      evaluate(statements, rest, Context.assign_constant(context, identifier, match))
    else
      _ -> {:error, {:did_not_match, {:regex, regex_source}, %{rest: rest}}}
    end
  end

  defp evaluate(
         [{:const, identifier, {:yield, {:ref, component_name}}} | statements],
         rest,
         %Context{components: components} = context
       )
       when is_map_key(components, component_name) do
    {:generator_function, _name, _args, body} = components[component_name]

    case evaluate(body, rest, context) do
      {:ok, value, %{rest: rest}} ->
        evaluate(statements, rest, Context.assign_constant(context, identifier, value))

      {:error, _reason} = tuple ->
        tuple
    end
  end

  @suggestion_threshold 0.77

  defp evaluate(
         [{:const, _, {:yield, {:ref, component_name}}} | _],
         _rest,
         %Context{components: components}
       ) do
    candidates =
      for {name, _} <- components,
          score = String.jaro_distance(name, component_name),
          score >= @suggestion_threshold,
          do: {name, score}

    suggestion =
      with candidates when candidates != [] <- candidates,
           {suggestion, _} <- Enum.max_by(candidates, fn {_, score} -> score end) do
        suggestion
      else
        _ -> nil
      end

    {:error, {:component_not_found, component_name, %{did_you_mean: suggestion}}}
  end

  # defp evaluate([{:const, [identifier], {:yield, yielded}} | statements], rest, _context)
  #      when is_binary(identifier) do
  #   {:error, {:did_not_match, identifier, %{rest: rest}}}
  # end

  defp evaluate([{:return, value}], rest, context) do
    return(value, rest, context)
  end

  defp evaluate([], rest, _context) do
    {:ok, nil, %{rest: rest}}
  end

  defp return({:ref, identifier}, rest, context) do
    actual_value = Map.get(context.constants, identifier)
    {:ok, actual_value, %{rest: rest}}
  end

  defp return(value, rest, context) when is_list(value) do
    return_list(value, [], rest, context)
  end

  defp return(value, rest, _context) do
    {:ok, value, %{rest: rest}}
  end

  defp return_list([{:ref, ref} | tail], transformed, rest, context) do
    actual_value = Map.get(context.constants, ref)
    return_list(tail, [actual_value | transformed], rest, context)
  end

  defp return_list([], transformed, rest, _context) do
    {:ok, transformed |> Enum.reverse(), %{rest: rest}}
  end
end
