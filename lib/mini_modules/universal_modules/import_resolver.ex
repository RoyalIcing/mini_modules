defmodule MiniModules.UniversalModules.ImportResolver do
  defmodule Context do
    defstruct imported: %{}

    def from_module(module_body, loader) do
      imported =
        Map.new(
          for statement <- module_body, result <- from_statement(statement, loader), do: result
        )

      %__MODULE__{imported: imported}
    end

    defp from_statement({:import, identifiers, {:url, source}}, loader) do
      {:ok, result} = loader.(source)

      for identifier <- identifiers,
          source_statement <- result,
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

  @spec transform(any, any) :: {:ok, list}
  def transform(module_body, loader) do
    context = Context.from_module(module_body, loader)

    processed =
      for statement <- module_body, new_statement <- process(statement, context) do
        new_statement
      end

    {:ok, processed}
  end

  defp process({:import, _identifiers, _}, _),
    do: []

  defp process({:export, [{:ref, ref}]}, %Context{imported: imported})
       when is_map_key(imported, ref) do
    [{:export, imported[ref]}]
  end

  defp process(statement, _context), do: [statement]
end
