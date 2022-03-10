defmodule MiniModules.UniversalModules.Parser do
  defmodule Error do
    require Record
    Record.defrecord(:error, reason: nil)
    Record.defrecord(:empty_reason, :empty, rest: nil)

    # @type empty :: record(:empty_reason, rest: String.t())

    # def empty(rest), do: error(reason: {:empty, rest})
    def empty(rest), do: error(reason: empty_reason(rest: rest))
  end

  def compose(submodule, input) do
    mod = Module.concat(__MODULE__, submodule)
    apply(mod, :decode, [input])
  end

  # def decode(input), do: Root.decode(input, [])
  def decode(input) when is_binary(input), do: switch(Root, input <> "\n", [])

  defp switch(submodule, input, result) do
    mod = Module.concat(__MODULE__, submodule)
    apply(mod, :decode, [input, result])
  end

  defmodule Root do
    defdelegate compose(submodule, input), to: MiniModules.UniversalModules.Parser

    def decode("", result), do: {:ok, Enum.reverse(result)}
    def decode(<<"\n", rest::bitstring>>, result), do: decode(rest, result)
    def decode(<<" ", rest::bitstring>>, result), do: decode(rest, result)
    def decode(<<";", rest::bitstring>>, result), do: decode(rest, result)

    def decode(<<"//", _::bitstring>> = input, result) do
      case compose(Comment, input) do
        {:ok, term, rest} ->
          decode(rest, [term | result])
      end
    end

    def decode(<<"/*", _::bitstring>> = input, result) do
      case compose(MultilineComment, input) do
        {:ok, term, rest} ->
          decode(rest, [term | result])
      end
    end

    def decode(<<"const ", _::bitstring>> = input, result) do
      case compose(Const, input) do
        {:ok, term, rest} ->
          decode(rest, [term | result])

        {:error, reason} ->
          {:error, reason}
      end
    end

    def decode(<<"export ", _::bitstring>> = input, result) do
      case compose(Export, input) do
        {:ok, term, rest} ->
          decode(rest, [term | result])

        {:error, reason} ->
          {:error, reason}
      end
    end

    def decode(<<"function", _::bitstring>> = input, result) do
      case compose(Function, input) do
        {:ok, term, rest} ->
          decode(rest, [term | result])

        {:error, reason} ->
          {:error, reason}
      end
    end

    def decode(<<"import ", _::bitstring>> = input, result) do
      case compose(Import, input) do
        {:ok, term, rest} ->
          decode(rest, [term | result])

        {:error, reason} ->
          {:error, reason}
      end
    end

    def decode("", result) do
      {:error, {:unexpected_eof, result}}
    end

    def decode(input, result) do
      {:error, {:invalid_input, input, result}}
    end
  end

  defmodule Export do
    defdelegate compose(submodule, input), to: MiniModules.UniversalModules.Parser

    def decode(<<"export ", rest::bitstring>>),
      do: decode(:expect_subject, rest)

    defp decode(context, <<" ", rest::bitstring>>),
      do: decode(context, rest)

    defp decode(:expect_subject, <<"{", rest::bitstring>>),
      do: decode({:expect_names, []}, rest)

    defp decode(:expect_subject, input) do
      with(
        {:error, :expected_const} <- MiniModules.UniversalModules.Parser.compose(Const, input),
        {:error, :expected_function} <-
          MiniModules.UniversalModules.Parser.compose(Function, input)
      ) do
        {:error, :expected_const_or_function}
      else
        {:ok, term, rest} ->
          {:ok, {:export, term}, rest}
      end
    end

    defp decode({:expect_names, names}, <<"}", rest::bitstring>>) do
      names = Enum.reverse(names)
      decode({:expect_from_or_end, names}, rest)
    end

    defp decode({:expect_names, names}, <<",", rest::bitstring>>),
      do: decode({:expect_names, names}, rest)

    defp decode({:expect_names, names}, input) do
      case compose(Identifier, input) do
        {:ok, identifier, rest} ->
          decode({:expect_names, [{:ref, identifier} | names]}, rest)

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp decode({:expect_from_or_end, names}, <<";", rest::bitstring>>),
      do: {:ok, {:export, names}, rest}

    # case MiniModules.UniversalModules.Parser.compose(Const, rest) do
    #   {:ok, term, rest} ->
    #     {:ok, {:export, term}, rest}

    #   {:error, reason} ->
    #     {:error, reason}
    # end
  end

  defmodule Import do
    defdelegate compose(submodule, input), to: MiniModules.UniversalModules.Parser

    def decode(<<"import ", rest::bitstring>>),
      do: decode(:expect_opening_curly, rest)

    defp decode(context, <<" ", rest::bitstring>>),
      do: decode(context, rest)

    defp decode(:expect_opening_curly, <<"*", rest::bitstring>>),
      do: decode(:star_expect_as, rest)

    defp decode(:star_expect_as, <<"as ", rest::bitstring>>),
      do: decode(:star_expect_name, rest)

    defp decode(:star_expect_name, input) do
      case compose(Identifier, input) do
        {:ok, identifier, rest} ->
          decode({:expect_from, {:alias, identifier}}, rest)

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp decode(:expect_opening_curly, <<"{", rest::bitstring>>),
      do: decode({:expect_names, []}, rest)

    defp decode({:expect_names, names}, <<"}", rest::bitstring>>) do
      names = Enum.reverse(names)
      decode({:expect_from, names}, rest)
    end

    defp decode({:expect_names, names}, <<",", rest::bitstring>>),
      do: decode({:expect_names, names}, rest)

    defp decode({:expect_names, names}, input) do
      case compose(Identifier, input) do
        {:ok, identifier, rest} ->
          decode({:expect_names, [identifier | names]}, rest)

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp decode({:expect_from, names}, <<"from ", rest::bitstring>>),
      do: decode({:expect_source, names}, rest)

    defp decode({:expect_source, names}, <<?", _::bitstring>> = input) do
      case compose(Expression, input) do
        {:ok, value, rest} ->
          decode({:expect_end, names, {:url, value}}, rest)

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp decode({:expect_end, names, source}, <<?;, rest::bitstring>>),
      do: {:ok, {:import, names, source}, rest}

    defp decode(context, input),
      do: {:error, {:unexpected_input, context, input}}
  end

  defmodule Function do
    defdelegate compose(submodule, input), to: MiniModules.UniversalModules.Parser

    def decode(<<"function", rest::bitstring>>),
      do: decode(%{generator_mark: nil, name: nil, args: nil, body: nil}, rest)

    def decode(<<_::bitstring>>),
      do: {:error, :expected_function}

    defp decode(context, <<" ", rest::bitstring>>),
      do: decode(context, rest)

    defp decode(%{generator_mark: nil, name: nil, args: nil} = context, <<"*", rest::bitstring>>),
      do: decode(%{context | generator_mark: true}, rest)

    defp decode(%{name: nil, args: nil} = context, <<"(", rest::bitstring>>),
      do: decode(%{context | args: {:open, []}}, rest)

    defp decode(%{name: reverse_name, args: nil} = context, <<"(", rest::bitstring>>) do
      name = reverse_name |> Enum.reverse() |> :binary.list_to_bin()
      decode(%{context | name: name, args: {:open, []}}, rest)
    end

    defp decode(%{args: {:open, args}} = context, <<")", rest::bitstring>>),
      do: decode(%{context | args: {:closed, args}}, rest)

    defp decode(%{args: {:closed, _}, body: nil} = context, <<"{", rest::bitstring>>),
      do: decode(%{context | body: {:open, []}}, rest)

    defp decode(
           %{args: {:closed, args}, name: name, body: {:open, body_items}} = context,
           <<"}", rest::bitstring>>
         ) do
      case context.generator_mark do
        true ->
          {:ok, {:generator_function, name, args, Enum.reverse(body_items)}, rest}

        nil ->
          {:ok, {:function, name, args, Enum.reverse(body_items)}, rest}
      end
    end

    defp decode(%{body: {:open, _}} = context, <<char::utf8, rest::bitstring>>)
         when char in [?\n, ?\t, ?;],
         do: decode(context, rest)

    defp decode(%{body: {:open, body_items}} = context, <<"//", _::bitstring>> = input) do
      case compose(Comment, input) do
        {:ok, term, rest} ->
          decode(%{context | body: {:open, [term | body_items]}}, rest)

        {:error, reason} ->
          {:error, {reason, body_items}}
      end
    end

    defp decode(%{body: {:open, body_items}} = context, <<"const ", _::bitstring>> = input) do
      case compose(Const, input) do
        {:ok, term, rest} ->
          decode(%{context | body: {:open, [term | body_items]}}, rest)

        {:error, reason} ->
          {:error, {reason, body_items}}
      end
    end

    defp decode(%{body: {:open, body_items}} = context, <<"yield ", _::bitstring>> = input) do
      case compose(Yield, input) do
        {:ok, term, rest} ->
          decode(%{context | body: {:open, [term | body_items]}}, rest)

        {:error, reason} ->
          {:error, {reason, body_items}}
      end
    end

    defp decode(%{body: {:open, body_items}} = context, <<"return ", _::bitstring>> = input) do
      case compose(Return, input) do
        {:ok, term, rest} ->
          decode(%{context | body: {:open, [term | body_items]}}, rest)

        {:error, reason} ->
          {:error, {reason, body_items}}
      end
    end

    defp decode(%{body: {:open, body_items}} = context, <<"function", _::bitstring>> = input) do
      case decode(input) do
        {:ok, term, rest} ->
          decode(%{context | body: {:open, [term | body_items]}}, rest)

        {:error, reason} ->
          {:error, {reason, body_items}}
      end
    end

    defp decode(%{name: nil, args: nil} = context, <<char::utf8, rest::bitstring>>),
      do: decode(%{context | name: [char]}, rest)

    defp decode(%{name: name, args: nil} = context, <<char::utf8, rest::bitstring>>) do
      name = [char | name]
      decode(%{context | name: name}, rest)
    end
  end

  defmodule Comment do
    def decode(<<"//", input::bitstring>>) do
      [comment, rest] = String.split(input, "\n", parts: 2)
      {:ok, {:comment, comment}, rest}
    end
  end

  defmodule MultilineComment do
    def decode(<<"/*", input::bitstring>>) do
      [comment, rest] = String.split(input, "*/", parts: 2)
      lines = String.split(comment, "\n")
      {:ok, {:comment, lines}, rest}
    end
  end

  defmodule Yield do
    def decode(<<"yield ", rest::bitstring>>) do
      case MiniModules.UniversalModules.Parser.compose(Expression, rest) do
        {:ok, term, rest} ->
          {:ok, {:yield, term}, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule Return do
    def decode(<<"return ", rest::bitstring>>) do
      case MiniModules.UniversalModules.Parser.compose(Expression, rest) do
        {:ok, term, rest} ->
          {:ok, {:return, term}, rest}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defmodule Const do
    defdelegate compose(submodule, input), to: MiniModules.UniversalModules.Parser

    def decode(<<"const ", rest::bitstring>>), do: decode({:expect_identifier, []}, rest)

    def decode(<<_::bitstring>>), do: {:error, :expected_const}

    defp decode({expect, _} = context, <<" ", rest::bitstring>>)
         when expect in [:expect_identifier, :expect_destructuring, :expect_equal],
         do: decode(context, rest)

    defp decode({:expect_identifier, []}, <<"[", rest::bitstring>>),
      do: decode({:expect_destructuring, {[], 1}}, rest)

    defp decode({:expect_identifier, []}, input) do
      case compose(Identifier, input) do
        {:ok, identifier, rest} ->
          decode({:expect_equal, identifier}, rest)

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp decode({:expect_destructuring, {identifiers, 0}}, <<",", rest::bitstring>>),
      do: decode({:expect_destructuring, {identifiers, 1}}, rest)

    defp decode({:expect_destructuring, {identifiers, n}}, <<",", rest::bitstring>>),
      do: decode({:expect_destructuring, {[nil | identifiers], n + 1}}, rest)

    defp decode({:expect_destructuring, {reversed, _}}, <<"]", rest::bitstring>>) do
      identifiers = reversed |> Enum.reverse()
      decode({:expect_equal, identifiers}, rest)
    end

    defp decode({:expect_destructuring, {identifiers, _}}, input) do
      case compose(Identifier, input) do
        {:ok, identifier, rest} ->
          decode({:expect_destructuring, {[identifier | identifiers], 0}}, rest)

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp decode({:expect_equal, payload}, <<"=", rest::bitstring>>) do
      decode({payload, :expect_expression, []}, rest)
    end

    # Skip whitespace
    defp decode({_, :expect_expression, []} = context, <<" ", rest::bitstring>>),
      do: decode(context, rest)

    defp decode({identifier, :expect_expression, expression}, ""),
      do: {:ok, {:const, identifier, expression}, ""}

    defp decode({identifier, :expect_expression, []}, <<"yield ", input::bitstring>>) do
      case compose(Expression, input) do
        {:ok, term, rest} ->
          {:ok, {:const, identifier, {:yield, term}}, rest}

        {:error, error} ->
          {:error, {:invalid_expression, error}}
      end
    end

    defp decode({identifier, :expect_expression, []}, input) do
      case compose(Expression, input) do
        {:ok, expression, rest} ->
          {:ok, {:const, identifier, expression}, rest}

        {:error, error} ->
          {:error, {:invalid_expression, error}}
      end
    end
  end

  defmodule CommaSeparatedList do
    # def decode(input, end_char), do: decode([], input)
  end

  defmodule Expression do
    import Unicode.Guards

    defdelegate compose(submodule, input), to: MiniModules.UniversalModules.Parser

    def decode(input), do: decode([], input)

    # def decode({:string, <<?", _::bitstring>> = input}) do
    #   decode([], input)
    # end

    defp decode(expression, <<";", rest::bitstring>>),
      do: {:ok, expression, rest}

    # Skip leading whitespace
    defp decode([] = context, <<" ", rest::bitstring>>), do: decode(context, rest)

    defp decode([], <<"true", rest::bitstring>>), do: decode(true, rest)
    defp decode([], <<"false", rest::bitstring>>), do: decode(false, rest)
    defp decode([], <<"null", rest::bitstring>>), do: decode(nil, rest)

    defp decode([], <<"Symbol()", rest::bitstring>>), do: decode({:symbol, nil}, rest)

    defp decode([], <<"Symbol(", rest::bitstring>>) do
      [encoded_json, rest] = String.split(rest, ");\n", parts: 2)

      case Jason.decode(encoded_json) do
        {:ok, value} ->
          {:ok, {:symbol, value}, rest}

        {:error, error} ->
          {:error, error}
      end
    end

    defp decode([], <<"new URL(", rest::bitstring>>) do
      with(
        {:ok, first, rest} when is_binary(first) <- decode([], rest),
        rest = String.trim_leading(rest)
      ) do
        case rest do
          <<")", rest::bitstring>> ->
            {:ok, {:url, first}, rest}

          <<",", second_raw::bitstring>> ->
            case decode([], second_raw) do
              {:ok, second, rest} ->
                case String.trim_leading(rest) do
                  <<")", rest::bitstring>> ->
                    {:ok, {:url, [relative: first, base: second]}, rest}

                  rest ->
                    {:error, {:expected_close, rest}}
                end

              other ->
                other
            end

          rest ->
            {:error, {:expected_argument_or_close, rest}}
        end
      end
    end

    defp decode([], <<"new Set(", rest::bitstring>>) do
      [encoded_json, rest] = String.split(rest, ");\n", parts: 2)

      case Jason.decode(encoded_json) do
        {:ok, value} ->
          {:ok, {:set, value}, rest}

        {:error, error} ->
          {:error, error}
      end
    end

    @string_regex ~r/^(?<STRING>(?>"(?>\\(?>["\\\/bfnrt]|u[a-fA-F0-9]{4})|[^"\\\0-\x1F\x7F]+)*"))/

    defp decode([], <<?", _::bitstring>> = input) do
      ["", encoded_json, rest] =
        Regex.split(@string_regex, input, parts: 2, include_captures: true)

      case Jason.decode(encoded_json) do
        {:ok, value} ->
          {:ok, value, rest}

        {:error, error} ->
          {:error, error}
      end
    end

    defp decode([], <<?[, rest::bitstring>>), do: decode({:array, []}, rest)

    defp decode({:array, items}, <<char::utf8, rest::bitstring>>) when is_whitespace(char) do
      decode({:array, items}, rest)
    end

    defp decode({:array, items}, <<",", rest::bitstring>>) do
      decode({:array, items}, rest)
    end

    defp decode({:array, reversed}, <<?], rest::bitstring>>) do
      items = reversed |> Enum.reverse()
      {:ok, items, rest}
    end

    defp decode({:array, items}, input) do
      case decode([], input) do
        {:ok, value, rest} ->
          decode({:array, [value | items]}, rest)

        {:error, error} ->
          {:error, error}
      end
    end

    defp decode(expression, <<",", _::bitstring>> = input), do: {:ok, expression, input}

    defp decode(expression, <<"\n", rest::bitstring>>), do: decode(expression, rest)

    defp decode(expression, <<"]", _::bitstring>> = input), do: {:ok, expression, input}

    # defp decode(expression, <<")", rest::bitstring>>), do: {:end_param, expression, rest}
    defp decode(expression, <<")", _::bitstring>> = input), do: {:ok, expression, input}

    # TODO: parse JSON by finding the end character followed by a semicolon + newline.
    # JSON strings cannoc contain literal newlines (it’s considered to be a control character),
    # so instead it must be encoded as "\n". So we can use this fast to know an actual newline is
    # outside the JSON value.
    # defp decode([], <<"{", rest::bitstring>>), do: decode([nil], rest)
    defp decode([], <<char::utf8, _::bitstring>> = input) when char in [?[, ?{] do
      [encoded_json, rest] = String.split(input, ";\n", parts: 2)

      case Jason.decode(encoded_json) do
        {:ok, value} ->
          {:ok, value, rest}

        {:error, error} ->
          {:error, error}
      end
    end

    defp decode([] = context, <<char::utf8, _::bitstring>> = source) when char in '0123456789' do
      case Float.parse(source) do
        :error ->
          {:error, {:invalid_number, context, source}}

        {f, rest} ->
          decode(f, rest)
      end
    end

    defp decode([] = context, <<"-", char::utf8, _::bitstring>> = source)
         when char in '0123456789' do
      case Float.parse(source) do
        :error ->
          {:error, {:invalid_number, context, source}}

        {f, rest} ->
          decode(f, rest)
      end
    end

    defp decode([], <<char::utf8, _::bitstring>> = input) when is_lower(char) or is_upper(char) do
      case compose(Identifier, input) do
        {:ok, identifier, rest} ->
          decode({:ref, identifier}, rest)

        {:error, reason} ->
          {:error, reason}
      end
    end

    @regex_regex ~r/^(?<REGEX>(?>\/(?>\\(?>[\/\\\(\[\]\)bBfnrtdwsS]|u[a-fA-F0-9]{4})|[^\/\0-\x1F\x7F]+)*\/))/

    defp decode([], <<?/, ?/, _::bitstring>> = input) do
      [comment, rest] = String.split(input, "\n", parts: 2)
      {:ok, {:comment, comment}, rest}
    end

    defp decode([], <<?/, _::bitstring>> = input) do
      ["", regex_source, rest] =
        Regex.split(@regex_regex, input, parts: 2, include_captures: true)

      regex_source = String.trim(regex_source, "/")

      {:ok, {:regex, regex_source}, rest}
    end

    defp decode({:ref, _} = called, <<"(", rest::bitstring>>), do: call(called, [], rest)

    defp call(called, args, <<char::utf8, rest::bitstring>>) when is_whitespace(char),
      do: call(called, args, rest)

    defp call(called, args, <<",", rest::bitstring>>), do: call(called, args, rest)

    defp call(called, args, <<?), rest::bitstring>>) do
      {:ok, {:call, called, args |> Enum.reverse()}, rest}
    end

    defp call(called, args, input) do
      case decode([], input) do
        {:ok, value, rest} ->
          call(called, [value | args], rest)

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defmodule KnownIdentifier do
    defmodule Symbol do
    end

    defmodule URL do
    end

    defmodule URLSearchParams do
    end

    def decode(<<"Symbol", rest::bitstring>>), do: {:ok, __MODULE__.Symbol, rest}
    def decode(<<"URL", rest::bitstring>>), do: {:ok, __MODULE__.URL, rest}

    def decode(<<"URLSearchParams", rest::bitstring>>),
      do: {:ok, __MODULE__.URLSearchParams, rest}

    def decode(_), do: {:error, :unknown_identifier}
  end

  defmodule Identifier do
    import Unicode.Guards

    def decode(input), do: decode([], input)

    defp decode([], <<char::utf8, rest::bitstring>>) when is_lower(char) or is_upper(char),
      do: decode([char], rest)

    defp decode(reverse_identifier, <<char::utf8, rest::bitstring>>)
         when is_lower(char) or is_upper(char) or is_digit(char) do
      decode([char | reverse_identifier], rest)
    end

    # defp decode([], _rest), do: {:error, :empty}
    defp decode([], rest), do: Error.empty(rest)

    defp decode(reverse_identifier, rest) do
      identifier = reverse_identifier |> Enum.reverse() |> :binary.list_to_bin()
      {:ok, identifier, rest}
    end
  end
end
