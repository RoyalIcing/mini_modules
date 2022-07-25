defmodule Molten do
  use Rustler, otp_app: :mini_modules, crate: "molten"

  def add(_, _), do: error()
  def js(_), do: error()

  defp error, do: :erlang.nif_error(:nif_not_loaded)
end
