defmodule MiniModules.Fetch.Get do
  defstruct [:url, :status, :headers, :data, :done]

  @timeout 5000

  def load(url_string) when is_binary(url_string) do
    {:ok, %URI{host: host, path: path, port: 443}} = URI.new(url_string)
    {:ok, conn} = Mint.HTTP.connect(:https, host, 443, mode: :passive, protocols: [:http1])
    {:ok, conn, request_ref} = Mint.HTTP.request(conn, "GET", path, [], nil)
    {:ok, conn, responses} = Mint.HTTP.recv(conn, 0, @timeout)
    Mint.HTTP.close(conn)
    reduce_responses(url_string, responses, request_ref)
  end

  defp reduce_responses(url_string, responses, ref) do
    map = Enum.reduce(responses, %{}, fn
      {:status, ^ref, code}, acc ->
        Map.put(acc, :status, code)

      {:headers, ^ref, headers}, acc ->
        Map.update(acc, :headers, headers, &(&1 ++ headers))

      {:data, ^ref, data}, acc ->
        Map.update(acc, :data, data, &(&1 <> data))

      {:done, ^ref}, acc ->
        Map.put(acc, :done, true)
    end)
    Map.merge(%__MODULE__{url: url_string}, map)
    # %__MODULE__{url: url_string | map}
  end
end
