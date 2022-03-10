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
    defstruct event_handlers: %{}, timer_handlers: []

    def from_function_body(statements, %Context{} = context) do
      case from_statement(%__MODULE__{}, statements, context) do
        {:ok, handlers} ->
          timer_handlers = Enum.sort_by(handlers.timer_handlers, fn {duration, _} -> duration end)
          handlers = put_in(handlers.timer_handlers, timer_handlers)
          {:ok, handlers}

        other ->
          other
      end

      # result = update_in(result.timer_handlers, &Enum.sort_by(&1, fn {duration, _} -> duration end))
      # result
    end

    defp from_statement(%__MODULE__{} = handlers, [], %Context{}), do: {:ok, handlers}

    defp from_statement(
           %__MODULE__{} = handlers,
           [
             {:yield, {:call, {:ref, "on"}, [event_name, {:ref, component_name}]}} | statements
           ],
           %Context{} = context
         )
         when is_binary(event_name) and is_map_key(context.components, component_name) do
      handlers = put_in(handlers.event_handlers[event_name], component_name)
      from_statement(handlers, statements, context)
    end

    defp from_statement(
           %__MODULE__{} = handlers,
           [
             {:yield, {:call, {:ref, "on"}, [duration, {:ref, component_name}]}} | statements
           ],
           %Context{} = context
         )
         when is_number(duration) and is_map_key(context.components, component_name) do
      handlers =
        update_in(handlers.timer_handlers, fn list ->
          [{duration * 1000, component_name} | list]
        end)

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

    def target_for_event(%__MODULE__{event_handlers: event_handlers}, event_name),
      do: event_handlers[event_name]

    def targets_in_timespan(%__MODULE__{timer_handlers: timer_handlers}, span_start, span_end) do
      timer_handlers
      |> Enum.filter(fn {duration, _} -> duration > span_start and duration <= span_end end)
    end
  end

  defmodule State do
    defstruct current: nil, overall_clock: 0, local_clock: 0, components: []

    def transition_to(%State{} = state, new_state, overall_clock_change) do
      %State{
        state
        | current: new_state,
          overall_clock: state.overall_clock + overall_clock_change,
          local_clock: 0
      }
    end

    def add_time(%State{} = state, duration) do
      %State{
        state
        | overall_clock: state.overall_clock + duration,
          local_clock: state.local_clock + duration
      }
    end
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
    {:ok, %State{current: component_name}, context}
  end

  defp return({:ref, _}, _context) do
    {:error, :unknown_initial_component}
  end

  defp return(_value, _context) do
    {:error, :invalid_return_value}
  end

  def apply_events(%State{} = state, context, []) do
    {:ok, %State{state | components: list_components(context)}}
  end

  def apply_events(%State{current: current_state} = state, %Context{} = context, [
        event_name | events
      ])
      when is_binary(event_name) do
    {:generator_function, _name, _args, body} = context.components[current_state]

    with({:ok, handlers} <- ComponentHandlers.from_function_body(body, context)) do
      case ComponentHandlers.target_for_event(handlers, event_name) do
        nil ->
          apply_events(state, context, events)

        new_state ->
          state = state |> State.transition_to(new_state, 0)
          apply_events(state, context, events)
      end
    end
  end

  def apply_events(
        %State{current: current_state, overall_clock: overall_clock, local_clock: local_clock} =
          state,
        %Context{} = context,
        [
          duration | events
        ]
      )
      when is_number(duration) do
    {:generator_function, _name, _args, body} = context.components[current_state]

    with({:ok, handlers} <- ComponentHandlers.from_function_body(body, context)) do
      {state, events} =
        case ComponentHandlers.targets_in_timespan(handlers, local_clock, local_clock + duration) do
          [] ->
            state = state |> State.add_time(duration)
            {state, events}

          [{target_duration, target} | _] ->
            state = state |> State.transition_to(target, target_duration - local_clock)
            remainder_duration = duration - target_duration
            events = if remainder_duration > 0, do: [remainder_duration | events], else: events
            {state, events}
        end

      apply_events(state, context, events)
    end

    # with({:ok, handlers} <- ComponentHandlers.from_function_body(body, context)) do
    #   apply_events(state, context, events)
    # end
  end

  defp list_components(%Context{} = context) do
    for {_, {_, from, _, body}} <- context.components,
        statement <- body,
        result <-
          (fn
             {:yield, {:call, {:ref, "on"}, [event_name, {:ref, to}]}}
             when is_binary(event_name) ->
               [{from, event_name, to}]

             {:yield, {:call, {:ref, "on"}, [duration, {:ref, to}]}} when is_number(duration) ->
               [{from, duration * 1000, to}]

             _ ->
               []
           end).(statement),
        do: result
  end
end
