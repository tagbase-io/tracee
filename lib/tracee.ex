defmodule Tracee do
  @moduledoc """
  Provides functionality to trace and assert expected function calls within Elixir processes.
  """

  import ExUnit.Assertions, only: [assert: 1]

  @name {:global, __MODULE__}

  @doc """
  Starts the tracer.
  """
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
               |> case do
                 list when is_list(list) -> List.last(list)
                 _ -> pid
               end

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

             send(test, {Tracee, :agent_updated})
           end, nil}
        )

        :dbg.p(:all, :c)

        server
    end
  end

  @doc """
  Sets an expectation for a function call with a specific arity and optional count.
  """
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

  @doc """
  Registers a verification check to be performed when the current test process exits.
  """
  def verify_on_exit!(_context \\ %{}) do
    test = self()

    ExUnit.Callbacks.on_exit(Tracer, fn ->
      verify(test)
      :dbg.stop()
    end)
  end

  @doc false
  def verify(pid) do
    # Wait for the agent to be update to date.
    receive do
      {Tracee, :agent_updated} -> nil
    after
      10 -> nil
    end

    case Agent.get(@name, & &1) do
      %{^pid => %{expectations: expectations, traces: traces}} when map_size(expectations) > 0 ->
        assert expectations == traces

      _ ->
        nil
    end
  end
end
