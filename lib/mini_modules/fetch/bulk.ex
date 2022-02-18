defmodule MiniModules.Fetch.Bulk do
  defstruct conns: %{}, requests: %{}

  def new(urls) do
    conns = for url <- urls, do: make_conn(url)
    %__MODULE__{conns: conns}
  end

  def make_conn(url_string) when is_binary(url_string) do
    {:ok, %URI{host: host, path: path, port: 443}} = URI.new(url_string)
    {:ok, conn} = Mint.HTTP.connect(:https, host, 443, protocols: [:http1])
    conn
  end
end
