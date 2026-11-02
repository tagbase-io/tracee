defmodule Tracee.Handler do
  @moduledoc false

  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # FIXME: This clause prevents `:erlang` calls from being traced. However,
  # disabling it would send numerous messages to the test process, causing
  # `verify/1` to fail.
  def trace({:trace, _pid, :call, {:erlang, _function, _args}}, unused), do: unused

  def trace({:trace, pid, :call, {module, function, args}}, unused) do
    GenServer.cast(__MODULE__, {:trace, pid, {module, function, length(args)}})
    unused
  end

  def trace({:trace, parent, :spawn, child, _mfa}, unused) do
    GenServer.cast(__MODULE__, {:spawn, parent, child})
    unused
  end

  def trace(_, unused), do: unused

  # GenServer API

  @impl true
  def init([]) do
    {:ok, %{expectations: [], traces: [], receivers: %{}, ancestors: %{}}}
  end

  @impl true
  def handle_cast({:expect, test, mfa, count}, state) do
    state = update_in(state, [:expectations], &(&1 ++ [{test, mfa, count}]))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:trace, pid, mfa}, state) do
    state = update_in(state, [:traces], &(&1 ++ [{pid, mfa}]))
    {:noreply, flush(state, find_ancestor(state.ancestors, pid))}
  end

  @impl true
  def handle_cast({:spawn, parent, child}, state) do
    state = put_in(state, [:ancestors, Access.key(child)], parent)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:remove, test}, state) do
    expectations = Enum.reject(state.expectations, &match?({^test, _, _}, &1))
    ancestors = Map.reject(state.ancestors, fn {pid, _} -> find_ancestor(state.ancestors, pid) == test end)
    receivers = Map.delete(state.receivers, test)

    {:noreply, %{state | expectations: expectations, ancestors: ancestors, receivers: receivers}}
  end

  @impl true
  def handle_call({:verify, test, receiver}, _from, state) do
    case Enum.filter(state.expectations, &match?({^test, _, _}, &1)) do
      [] ->
        {:reply, [], state}

      expectations ->
        state = put_in(state, [:receivers, Access.key(test)], receiver)
        {:reply, expectations, flush(state, test)}
    end
  end

  # Forwards the test's traces to its receiver once `verify/1` registered one.
  # Traces that arrive later are forwarded by the `:trace` cast as they come.
  defp flush(state, test) do
    case state.receivers do
      %{^test => receiver} ->
        {traces, rest} = Enum.split_with(state.traces, fn {pid, _} -> find_ancestor(state.ancestors, pid) == test end)

        for {_, mfa} <- traces do
          send(receiver, {Tracee, test, mfa})
        end

        %{state | traces: rest}

      _ ->
        state
    end
  end

  defp find_ancestor(map, pid) when is_map_key(map, pid), do: find_ancestor(map, map[pid])
  defp find_ancestor(_map, pid), do: pid
end
