defmodule MiniModules.UniversalModules.YieldParser do
  defmodule Context do
    defstruct reply: nil
  end

  def run_parser(module_body, input) do
    results = for statement <- module_body, result <- run(statement, input), do: result

    case results do
      [result] -> result
      [] -> {:error, :expected_exported_generator_function}
      results -> {:error, {:too_many_exported_generator_functions, results}}
    end
  end

  defp run({:export, {:generator_function, _name, _args, body}}, input) do
    [evaluate(body, input, %Context{})]
  end

  defp run(_, _), do: []

  defp regex(source, rest) do
    case Regex.compile(source) do
      {:ok, regex} ->
        ["", matched, rest] = Regex.split(regex, rest, parts: 2, include_captures: true)
        {:ok, matched, rest}

      {:error, reason} ->
        {:error, {:invalid_regex, source, reason}}
    end
  end

  defp evaluate([{:yield, value} | statements], rest, context) when is_binary(value) do
    size = byte_size(value)

    case rest do
      <<prefix::size(size)-binary, rest::bitstring>> when prefix == value ->
        evaluate(statements, rest, context)

      _ ->
        {:error, {:did_not_match, value, %{rest: rest}}}
    end
  end

  defp evaluate([{:yield, [ref: "mustEnd"]} | statements], rest, context) do
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
    with {:ok, reply, rest} <- regex(regex_source, rest) do
      evaluate(statements, rest, %Context{context | reply: reply})
    else
      _ -> {:error, {:did_not_match, {:regex, regex_source}, %{rest: rest}}}
    end

  end

  # defp evaluate([{:const, [identifier], {:yield, yielded}} | statements], rest, _context)
  #      when is_binary(identifier) do
  #   {:error, {:did_not_match, identifier, %{rest: rest}}}
  # end

  defp evaluate([{:return, value}], rest, _context) do
    {:ok, value, %{rest: rest}}
  end

  defp evaluate([], rest, _context) do
    {:ok, nil, %{rest: rest}}
  end
end
