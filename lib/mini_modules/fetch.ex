defmodule MiniModules.Fetch do
  def get(url_string) when is_binary(url_string) do
    __MODULE__.Get.load(url_string)
  end
end
