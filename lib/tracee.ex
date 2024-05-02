defmodule Tracee do
  @moduledoc """
  Provides functionality to trace and assert expected function calls within Elixir processes.
  """

  import ExUnit.Assertions

  def child_spec([]) do
    %{id: __MODULE__, type: :worker, start: {__MODULE__, :start_link, []}}
  end

  @doc """
  Starts the tracer.
  """
  def start_link do
    case :dbg.tracer(:process, {&Tracee.Handler.trace/2, :unused}) do
      {:ok, server} ->
        :dbg.p(:all, :c)

        :dbg.tp(:erlang, :spawn, [{:_, [], [{:return_trace}]}])
        :dbg.tp(:erlang, :spawn_link, [{:_, [], [{:return_trace}]}])
        :dbg.tp(:erlang, :spawn_monitor, [{:_, [], [{:return_trace}]}])
        :dbg.tp(:erlang, :spawn_opt, [{:_, [], [{:return_trace}]}])

        {:ok, server}

      {:error, :already_started} ->
        {:error, :already_started}
    end
  end

  @doc """
  Sets an expectation for a function call with a specific arity and optional count.
  """
  def expect(module, function, arity, count \\ 1) do
    GenServer.cast(Tracee.Handler, {:expect, self(), {module, function, arity}, count})
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
    end)
  end

  @assert_receive_timeout Application.compile_env(
                            :tracee,
                            :assert_receive_timeout,
                            Application.compile_env!(:ex_unit, :assert_receive_timeout)
                          )

  @refute_receive_timeout Application.compile_env(
                            :tracee,
                            :refute_receive_timeout,
                            Application.compile_env!(:ex_unit, :refute_receive_timeout)
                          )

  @doc """
  Verifies that all expected function calls have been received and nothing else.
  """
  def verify(test \\ self()) do
    case GenServer.call(Tracee.Handler, {:verify, test, self()}) do
      [] ->
        nil

      expectations ->
        for {_, mfa} <- expectations do
          assert_receive {Tracee, ^test, ^mfa},
                         @assert_receive_timeout,
                         "Expected #{format_mfa(mfa)} to be called in #{inspect(test)}"
        end

        refute_receive {Tracee, _, mfa},
                       @refute_receive_timeout,
                       "No (more) expectations defined for #{format_mfa(mfa)} in #{inspect(test)}"

        GenServer.cast(Tracee.Handler, {:remove, test})
    end
  end

  defp format_mfa({module, function, arity}) do
    "#{inspect(module)}.#{function}/#{arity}"
  end
end
