defmodule MiniModules.UniversalModules.ImportResolver do
  defmodule Context do
    defstruct imported_modules: %{}, matched_statements: %{}, local_statements: %{}

    def from_module(module_body, loader) do
      import_sources =
        MapSet.new(for {:import, _identifiers, {:url, source}} <- module_body, do: source)

      # imported_modules =
      #   Map.new(
      #     for source <- import_sources,
      #         result = loader.(source),
      #         match?({:ok, _}, result),
      #         {:ok, result} = result,
      #         result != nil,
      #         do: {source, result}
      #   )

      imported_modules =
        Enum.reduce_while(import_sources, [], fn source, acc ->
          case loader.(source) do
            {:ok, nil} ->
              {:cont, acc}

            {:ok, result} ->
              {:cont, [{source, result} | acc]}

            {:error, reason} ->
              {:halt, {:error, reason}}

            :error ->
              {:halt, :error}
          end
        end)

      case imported_modules do
        {:error, _} = result ->
          result

        pairs ->
          imported_modules = Map.new(pairs)

          imported =
            for statement <- module_body,
                result <- from_statement(statement, imported_modules),
                do: result

          {matched_statements, local_statements} =
            imported
            |> Enum.split_with(fn s -> match?({:matched_import, _, _}, s) end)

          matched_statements =
            matched_statements
            |> Map.new(fn {:matched_import, name, statement} -> {name, statement} end)

          local_statements =
            local_statements
            |> Map.new(fn {:local, name, statement} -> {name, statement} end)

          {:ok,
           %__MODULE__{
             imported_modules: imported_modules,
             matched_statements: matched_statements,
             local_statements: local_statements
           }}
      end

      # imported_modules =
      #   Map.new(
      #     for source <- import_sources,
      #         result = loader.(source),
      #         match?({:ok, _}, result),
      #         {:ok, result} = result,
      #         result != nil,
      #         do: {source, result}
      #   )
    end

    defp from_statement({:import, identifiers, {:url, source}}, imported_modules)
         when is_map_key(imported_modules, source) do
      imported_module = imported_modules[source]

      identifiers = MapSet.new(identifiers)

      for source_statement <- imported_module,
          resolved <- lookup(identifiers, source_statement) do
        resolved
      end

      # for identifier <- identifiers,
      #     source_statement <- imported_module,
      #     resolved <- lookup(identifier, source_statement) do
      #   {identifier, resolved}
      # end
    end

    defp from_statement(_, _), do: []

    defp identify({:export, {:const, name, _}}), do: name

    defp identify({:export, {:function, name, _, _}}), do: name

    defp identify({:export, {:generator_function, name, _, _}}), do: name

    defp identify({:const, name, _}), do: name

    defp identify({:function, name, _, _}), do: name

    defp identify({:generator_function, name, _, _}), do: name

    defp identify(_), do: nil

    defp lookup(identifiers, statement) do
      identifier = identify(statement)

      case {identifier, statement, MapSet.member?(identifiers, identifier)} do
        {nil, _, _} ->
          []

        {name, {:export, exported}, true} ->
          [{:matched_import, name, exported}]

        {name, {:export, exported}, false} ->
          [{:local, name, exported}]

        {name, statement, false} ->
          [{:local, name, statement}]

        _ ->
          []
      end
    end
  end

  def transform(module_body, loader) do
    case Context.from_module(module_body, loader) do
      {:ok, context} ->
        processed =
          for statement <- module_body, new_statement <- process(statement, context) do
            new_statement
          end

        processed = Map.values(context.local_statements) ++ processed

        {:ok, processed, %{imported_modules: context.imported_modules}}

      other ->
        other
    end
  end

  defp process({:import, _identifiers, _}, _),
    # TODO: recursive imports
    do: []

  defp process({:export, [{:ref, ref}]}, %Context{matched_statements: matched_statements})
       when is_map_key(matched_statements, ref) do
    [{:export, matched_statements[ref]}]
  end

  defp process(statement, _context), do: [statement]
end
