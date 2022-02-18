defmodule MiniModules.Fetch.BulkSerial do
  defstruct [:responses]

  alias MiniModules.Fetch.Get

  def new(urls) do
    responses = for url <- urls, do: Get.load(url)
    %__MODULE__{responses: responses}
  end
end
