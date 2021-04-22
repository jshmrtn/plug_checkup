defmodule PlugCheckup.Check.Runner do
  @moduledoc """
  Executes the given checks asynchronously respecting the given timeout for each of the checks,
  and decides whether the execution was successful or not.
  """
  alias PlugCheckup.Check

  @spec async_run([PlugCheckup.Check.t()], pos_integer(), check_name_selector :: String.t() | nil) ::
          tuple()
  def async_run(checks, timeout, check_name_selector \\ nil) do
    results =
      checks
      |> filter_by_check_selector(check_name_selector)
      |> execute_all(timeout)
      |> Enum.zip(checks)
      |> Enum.map(&task_to_result/1)

    if Enum.all?(results, fn r -> r.result == :ok end) do
      {:ok, results}
    else
      {:error, results}
    end
  end

  @spec execute_all([PlugCheckup.Check.t()], pos_integer()) :: Enum.t()
  def execute_all(checks, timeout) do
    async_options = [timeout: timeout, on_timeout: :kill_task]
    Task.async_stream(checks, &Check.execute/1, async_options)
  end

  @spec task_to_result({
          {:ok, PlugCheckup.Check.t()},
          any
        }) :: PlugCheckup.Check.t()
  def task_to_result({{:ok, result}, _check}) do
    result
  end

  @spec task_to_result({
          {:exit, any},
          PlugCheckup.Check.t()
        }) :: PlugCheckup.Check.t()
  def task_to_result({{:exit, reason}, check}) do
    %{check | result: {:error, reason}}
  end

  defp filter_by_check_selector(checks, check_name_selector)
  defp filter_by_check_selector(checks, nil), do: checks

  defp filter_by_check_selector(checks, check_name_selector) when is_binary(check_name_selector),
    do: Enum.filter(checks, &match?(%Check{name: ^check_name_selector}, &1))
end
