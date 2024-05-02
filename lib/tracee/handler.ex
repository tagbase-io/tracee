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

  def trace({:trace, parent, :return_from, {:erlang, _, _}, {child, _ref}}, unused) do
    GenServer.cast(__MODULE__, {:spawn, parent, child})
    unused
  end

  def trace({:trace, parent, :return_from, {:erlang, _, _}, child}, unused) do
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
    state = update_in(state, [:expectations], &(&1 ++ List.duplicate({test, mfa}, count)))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:trace, pid, mfa}, state) do
    state = update_in(state, [:traces], &(&1 ++ [{pid, mfa}]))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:spawn, parent, child}, state) do
    state = put_in(state, [:ancestors, Access.key(child)], parent)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:remove, test}, state) do
    {_, state} =
      get_and_update_in(state, [:expectations, Access.all()], fn
        {^test, _} -> :pop
        {test, mfa} -> {{test, mfa}, {test, mfa}}
      end)

    {:noreply, state}
  end

  @impl true
  def handle_call({:verify, test, receiver}, _from, state) do
    expectations = Enum.filter(state.expectations, &(elem(&1, 0) == test))
    state = put_in(state, [:receivers, Access.key(test)], receiver)

    {:reply, expectations, state, {:continue, {:flush, test}}}
  end

  @impl true
  def handle_continue({:flush, test}, state) do
    send(self(), {:flush, test})
    {:noreply, state}
  end

  @impl true
  def handle_info({:flush, test}, state) do
    case get_in(state, [:receivers, Access.key(test)]) do
      nil ->
        {:noreply, state}

      receiver ->
        # Find all traces that were called in the test process or any child process.
        {traces, state} =
          pop_in(state, [:traces, Access.filter(&match?(^test, find_ancestor(state.ancestors, elem(&1, 0), test)))])

        for {_, mfa} <- traces do
          send(receiver, {Tracee, test, mfa})
        end

        {:noreply, state, {:continue, {:flush, test}}}
    end
  end

  defp find_ancestor(_map, pid, ancestor) when pid == ancestor, do: ancestor

  defp find_ancestor(map, pid, ancestor) when is_map_key(map, pid) do
    find_ancestor(map, map[pid], ancestor)
  end

  defp find_ancestor(_map, pid, _ancestor), do: pid
end
