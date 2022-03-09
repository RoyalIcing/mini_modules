defmodule MiniModules.Fetch.Get do
  defstruct [:url, :status, :headers, :data, :done]

  @timeout 5000

  def load(url_string) when is_binary(url_string) do
    {:ok, url} = URI.new(url_string)

    case load(url, url_string) do
      %__MODULE__{status: status, headers: headers} = resp when status >= 300 and status < 400 ->
        case Enum.find(headers, fn {key, _} -> key == "location" end) do
          nil ->
            resp

          {_, location} ->
            IO.puts("Following #{status} redirect to #{location}")
            case URI.new(location) do
              {:ok, location_url} ->
                # TODO: use existing conn if host is the same.
                load(location_url, url_string)

              _ ->
                {:error, {:invalid_url, location}}
            end
        end

      other ->
        other
    end
  end

  def load(%URI{host: host, path: path, port: 443}, url_string) do
    start = System.monotonic_time(:millisecond)
    {:ok, conn} = Mint.HTTP.connect(:https, host, 443, mode: :passive, protocols: [:http1])
    {:ok, conn, request_ref} = Mint.HTTP.request(conn, "GET", path, [], nil)
    {:ok, conn, responses} = Mint.HTTP.recv(conn, 0, @timeout)
    # {:ok, conn, responses2} = Mint.HTTP.recv(conn, 0, @timeout)
    # responses = responses ++ responses2
    Mint.HTTP.close(conn)
    result = reduce_responses(url_string, responses, request_ref)

    IO.puts(
      "Loaded #{url_string} in #{System.monotonic_time(:millisecond) - start}ms. #{inspect(result.done)}"
    )

    result
  end

  def load_text(url_string) when is_binary(url_string) do
    %{data: data} = load(url_string)
    data
  end

  defp reduce_responses(url_string, responses, ref) do
    map =
      Enum.reduce(responses, %{}, fn
        {:status, ^ref, code}, acc ->
          IO.puts("status #{code}")
          Map.put(acc, :status, code)

        {:headers, ^ref, headers}, acc ->
          IO.puts("headers")
          Map.update(acc, :headers, headers, &(&1 ++ headers))

        {:data, ^ref, data}, acc ->
          IO.puts("data")
          Map.update(acc, :data, data, &(&1 <> data))

        {:done, ^ref}, acc ->
          IO.puts("done")
          Map.put(acc, :done, true)
      end)

    Map.merge(%__MODULE__{url: url_string}, map)
    # %__MODULE__{url: url_string | map}
  end
end
