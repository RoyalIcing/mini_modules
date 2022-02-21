defmodule MiniModules.UniversalModules.ImportResolver do
  defmodule Context do
    defstruct imported_modules: %{}, imported_identifiers: %{}

    def from_module(module_body, loader) do
      import_sources =
        MapSet.new(for {:import, _identifiers, {:url, source}} <- module_body, do: source)

      imported_modules =
        Map.new(
          for source <- import_sources, {:ok, result} = loader.(source), do: {source, result}
        )

      imported_identifiers =
        Map.new(
          for statement <- module_body,
              result <- from_statement(statement, imported_modules),
              do: result
        )

      %__MODULE__{imported_modules: imported_modules, imported_identifiers: imported_identifiers}
    end

    defp from_statement({:import, identifiers, {:url, source}}, imported_modules)
         when is_map_key(imported_modules, source) do
      imported_module = imported_modules[source]

      for identifier <- identifiers,
          source_statement <- imported_module,
          resolved <- lookup(identifier, source_statement) do
        {identifier, resolved}
      end
    end

    defp from_statement(_, _), do: []

    defp lookup(identifier, {:export, {:const, name, _} = exported}) when identifier == name,
      do: [exported]

    defp lookup(identifier, {:export, {:function, name, _, _} = exported})
         when identifier == name,
         do: [exported]

    defp lookup(identifier, {:export, {:generator_function, name, _, _} = exported})
         when identifier == name,
         do: [exported]

    defp lookup(_, _), do: []
  end

  def transform(module_body, loader) do
    context = Context.from_module(module_body, loader)

    processed =
      for statement <- module_body, new_statement <- process(statement, context) do
        new_statement
      end

    {:ok, processed, %{imported_modules: context.imported_modules}}
  end

  defp process({:import, _identifiers, _}, _),
    do: []

  defp process({:export, [{:ref, ref}]}, %Context{imported_identifiers: imported_identifiers})
       when is_map_key(imported_identifiers, ref) do
    [{:export, imported_identifiers[ref]}]
  end

  defp process(statement, _context), do: [statement]
end
