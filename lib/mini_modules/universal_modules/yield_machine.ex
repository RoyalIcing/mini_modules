defmodule MiniModules.UniversalModules.YieldMachine do
  defmodule Context do
    defstruct components: %{}

    def from_module(module_body) do
      components =
        Map.new(for statement <- module_body, result <- from_statement(statement), do: result)

      %__MODULE__{components: components}
    end

    defp from_statement({:generator_function, name, _args, _body} = statement),
      do: [{name, statement}]

    defp from_statement(_), do: []

    def register_component(%__MODULE__{} = context, identifier, component) do
      put_in(context.components[identifier], component)
    end
  end

  defmodule ComponentHandlers do
    defstruct event_handlers: %{}

    def from_function_body(statements) do
      from_statement(%__MODULE__{}, statements)
    end

    defp from_statement(%__MODULE__{} = handlers, []), do: handlers

    defp from_statement(%__MODULE__{} = handlers, [{:yield, {:call, {:ref, "on"}, [event_name, {:ref, component_name}]}} | statements]) do
      handlers = put_in(handlers.event_handlers[event_name], component_name)
      from_statement(handlers, statements)
    end

    defp from_statement(%__MODULE__{} = handlers, [_ | statements]), do: from_statement(handlers, statements)

    def target_for_event(%__MODULE__{} = handlers, event_name), do: handlers.event_handlers[event_name]
  end

  def interpret_machine(module_body, events \\ []) do
    context = Context.from_module(module_body)

    results = for statement <- module_body, result <- interpret(statement, context), do: result

    case results do
      [result] -> result |> apply_events(events)
      [] -> {:error, :expected_exported_function}
      results -> {:error, {:too_many_exports, results}}
    end
  end

  defp interpret({:export, {:generator_function, _name, _args, body}}, context) do
    [evaluate(body, context)]
  end

  defp interpret({:export, {:function, _name, _args, body}}, context) do
    [evaluate(body, context)]
  end

  defp interpret(_, _), do: []

  defp evaluate([{:comment, _} | statements], context), do: evaluate(statements, context)

  defp evaluate([{:generator_function, name, [], _body} = component | statements], context) do
    context = context |> Context.register_component(name, component)
    evaluate(statements, context)
  end

  defp evaluate([], _context) do
    {:error, :expected_return}
  end

  defp evaluate([{:return, value}], context) do
    return(value, context)
  end

  defp return({:ref, identifier}, context) do
    # actual_value = Map.get(context.constants, identifier)
    {:ok, %{state: identifier}, context}
  end

  defp return(_value, _context) do
    {:error, :invalid_return_value}
  end

  def apply_events({:ok, %{state: _current_state} = result, _context}, []) do
    {:ok, result}
  end

  def apply_events({:ok, %{state: current_state}, %Context{} = context} = current, [event_name | events]) when is_binary(event_name) do
    {:generator_function, _name, _args, body} = context.components[current_state]
    handlers = ComponentHandlers.from_function_body(body)

    case ComponentHandlers.target_for_event(handlers, event_name) do
      nil ->
        apply_events(current, events)

      new_state ->
        apply_events({:ok, %{state: new_state}, context}, events)
    end
  end
end