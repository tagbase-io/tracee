defmodule Tracee do
  @moduledoc """
  This Elixir library offers functionality to trace and assert expected function
  calls within concurrent Elixir processes.

  This allows you to ensure that destructive and/or expensive functions are only
  called the expected number of times. For more information, see [the Elixir forum
  post](https://elixirforum.com/t/tracing-and-asserting-function-calls/63035) that
  motivated the development of this library.

  ## Usage

      defmodule ModuleTest do
        use ExUnit.Case, async: true

        import Tracee

        setup :verify_on_exit!

        describe "fun/0" do
          test "calls expensive function only once" do
            expect(AnotherModule, :expensive_fun, 1)

            assert Module.fun()
          end

          test "calls expensive function only once from another process" do
            expect(AnotherModule, :expensive_fun, 1)

            assert fn -> Module.fun() end
                   |> Task.async()
                   |> Task.await()
          end
        end
      end
  """

  import ExUnit.Assertions

  alias Tracee.Handler

  @doc false
  def child_spec([]) do
    %{id: __MODULE__, type: :worker, start: {__MODULE__, :start_link, []}}
  end

  @doc """
  Starts the tracer.
  """
  @spec start_link() :: {:ok, pid()} | {:error, :already_started}
  def start_link do
    case :dbg.tracer(:process, {&Handler.trace/2, :unused}) do
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
  Sets an expectation for a function call with a specific arity and optional
  count.

  ## Examples

      # expect AnotherModule.expensive_fun/0 to be called once
      Tracee.expect(AnotherModule, :expensive_fun, 0)

      # expect AnotherModule.expensive_fun/1 to be called twice
      Tracee.expect(AnotherModule, :expensive_fun, 1, 2)

  """
  @spec expect(module(), atom(), pos_integer(), pos_integer()) :: :ok
  def expect(module, function, arity, count \\ 1) when is_integer(count) and count > 0 do
    GenServer.cast(Handler, {:expect, self(), {module, function, arity}, count})
    :dbg.tp(module, function, arity, [])

    :ok
  end

  @doc """
  Registers a verification check to be performed when the current test process
  exits.

  ## Examples

      defmodule ModuleTest do
        use ExUnit.Case, async: true

        import Tracee

        setup :verify_on_exit!
      end
  """
  @spec verify_on_exit!(map()) :: :ok
  def verify_on_exit!(_context \\ %{}) do
    test = self()

    ExUnit.Callbacks.on_exit(Tracee, fn ->
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
  @spec verify(pid()) :: :ok
  def verify(test \\ self()) do
    case GenServer.call(Handler, {:verify, test, self()}) do
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

        GenServer.cast(Handler, {:remove, test})
    end

    :ok
  end

  defp format_mfa({module, function, arity}) do
    "#{inspect(module)}.#{function}/#{arity}"
  end
end
