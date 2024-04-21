defmodule Tracee do
  @moduledoc false

  import ExUnit.Assertions, only: [assert: 1]

  @name {:global, __MODULE__}

  def start_link do
    case Agent.start_link(fn -> %{} end, name: @name) do
      {:error, {:already_started, _}} ->
        :ignore

      server ->
        :dbg.start()

        :dbg.tracer(
          :process,
          {fn {:trace, pid, :call, {module, function, args}}, _state ->
             test =
               pid
               |> :erlang.process_info()
               |> get_in([:dictionary, :"$ancestors"])
               |> List.last()

             Agent.update(@name, fn state ->
               state
               |> update_in([test], fn
                 nil -> %{expectations: %{}, traces: %{}}
                 map -> map
               end)
               |> update_in([test, :traces, {module, function, length(args)}], fn
                 nil -> 1
                 count -> count + 1
               end)
             end)
           end, nil}
        )

        :dbg.p(:all, :c)

        server
    end
  end

  def expect(module, function, arity, count \\ 1) do
    test = self()

    Agent.update(@name, fn state ->
      state
      |> update_in([test], fn
        nil -> %{expectations: %{}, traces: %{}}
        map -> map
      end)
      |> put_in([test, :expectations, {module, function, arity}], count)
    end)

    :dbg.tp(module, function, arity, [])

    :ok
  end

  def verify_on_exit! do
    test = self()
    ExUnit.Callbacks.on_exit(Tracer, fn -> verify(test) end)
  end

  defp verify(pid) do
    case Agent.get(@name, &Map.get(&1, pid)) do
      %{expectations: expectations, traces: traces} when map_size(expectations) > 0 -> assert expectations == traces
      _ -> nil
    end
  end
end
