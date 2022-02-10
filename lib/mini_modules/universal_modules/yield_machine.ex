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

    def from_function_body(statements, %Context{} = context) do
      from_statement(%__MODULE__{}, statements, context)
    end

    defp from_statement(%__MODULE__{} = handlers, [], %Context{}), do: {:ok, handlers}

    defp from_statement(
           %__MODULE__{} = handlers,
           [
             {:yield, {:call, {:ref, "on"}, [event_name, {:ref, component_name}]}} | statements
           ],
           %Context{} = context
         )
         when is_map_key(context.components, component_name) do
      handlers = put_in(handlers.event_handlers[event_name], component_name)
      from_statement(handlers, statements, context)
    end

    defp from_statement(
           %__MODULE__{},
           [{:yield, {:call, {:ref, "on"}, on_args}} | _statements],
           %Context{}
         ) do
      {:error, {:invalid_on, on_args}}
    end

    defp from_statement(%__MODULE__{} = handlers, [_ | statements], %Context{} = context),
      do: from_statement(handlers, statements, context)

    def target_for_event(%__MODULE__{} = handlers, event_name),
      do: handlers.event_handlers[event_name]
  end

  def interpret_machine(module_body, events \\ []) do
    context = Context.from_module(module_body)

    results = for statement <- module_body, result <- interpret(statement, context), do: result

    case results do
      [{:error, _} = error] -> error
      [{:ok, state, context}] -> apply_events(state, context, events)
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

  defp return({:ref, component_name}, context)
       when is_map_key(context.components, component_name) do
    {:ok, %{current: component_name}, context}
  end

  defp return({:ref, _}, _context) do
    {:error, :unknown_initial_component}
  end

  defp return(_value, _context) do
    {:error, :invalid_return_value}
  end

  def apply_events(%{current: current}, context, []) do
    {:ok, %{current: current, components: list_components(context)}}
  end

  def apply_events(%{current: current_state} = state, %Context{} = context, [
        event_name | events
      ])
      when is_binary(event_name) do
    {:generator_function, _name, _args, body} = context.components[current_state]

    with({:ok, handlers} <- ComponentHandlers.from_function_body(body, context)) do
      case ComponentHandlers.target_for_event(handlers, event_name) do
        nil ->
          apply_events(state, context, events)

        new_state ->
          apply_events(%{current: new_state}, context, events)
      end
    end
  end

  defp list_components(%Context{} = context) do
    for {_, {_, from, _, body}} <- context.components,
        statement <- body,
        result <-
          (fn
             {:yield, {:call, {:ref, "on"}, [event_name, {:ref, to}]}} -> [{from, event_name, to}]
             _ -> []
           end).(statement),
        do: result
  end
end
