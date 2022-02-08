defmodule MiniModules.UniversalModules.YieldParser do
  def run_parser(module_body, input) do
    results = for statement <- module_body, result <- run(statement, input), do: result

    case results do
      [result] -> result
      [] -> {:error, :expected_exported_generator_function}
      results -> {:error, {:too_many_exported_generator_functions, results}}
    end
  end

  defp run({:export, {:generator_function, _name, _args, body}}, input) do
    [evaluate(body, input, [])]
  end

  defp run(_, _), do: []

  # defp evaluate([{:yield, value} | statements], <<value, rest::bitstring>>, context) do
  #   evaluate(statements, rest, context)
  # end
  defp evaluate([{:yield, value} | statements], rest, context) when is_binary(value) do
    size = byte_size(value)

    case rest do
      <<prefix::size(size)-binary, rest::bitstring>> when prefix == value ->
        evaluate(statements, rest, context)

      _ ->
        {:error, {:did_not_match, value, %{rest: rest}}}
    end
  end

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

  defp evaluate([{:return, value}], rest, _context) do
    {:ok, value, %{rest: rest}}
  end

  defp evaluate([], rest, _context) do
    {:ok, nil, %{rest: rest}}
  end
end
