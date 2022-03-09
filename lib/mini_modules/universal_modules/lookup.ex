defmodule MiniModules.UniversalModules.Lookup do
  def identify({:export, {:const, name, _}}), do: name

  def identify({:export, {:function, name, _, _}}), do: name

  def identify({:export, {:generator_function, name, _, _}}), do: name

  def identify({:const, name, _}), do: name

  def identify({:function, name, _, _}), do: name

  def identify({:generator_function, name, _, _}), do: name

  def identify(_), do: nil

  def pair({:export, {:const, name, value}}), do: {name, value}

  def pair({:export, {:function, name, _, _} = f}), do: {name, f}

  def pair({:export, {:generator_function, name, _, _} = f}), do: {name, f}

  def pair({:const, name, value}), do: {name, value}

  def pair({:function, name, _, _} = f), do: {name, f}

  def pair({:generator_function, name, _, _} = f), do: {name, f}

  def pair(_), do: nil
end
