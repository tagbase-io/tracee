defmodule TraceeTest do
  use ExUnit.Case

  import Tracee

  defmodule TestModule do
    @moduledoc false
    def fun, do: :ok
    def fun(_arg), do: :ok
  end

  describe "expect/3" do
    setup :verify_on_exit!

    test "ensures function is called once" do
      expect(TestModule, :fun, 0)
      expect(TestModule, :fun, 1)

      TestModule.fun()
      TestModule.fun(:ok)
    end

    test "ensures function is called n times" do
      expect(TestModule, :fun, 0, 2)
      expect(TestModule, :fun, 1, 2)

      TestModule.fun()
      TestModule.fun(:ok)
      TestModule.fun()
      TestModule.fun(:ok)
    end

    test "ensures function is called once from another task" do
      expect(TestModule, :fun, 0)

      fn -> TestModule.fun() end
      |> Task.async()
      |> Task.await()
    end

    test "ensures function is called n times from other tasks" do
      expect(TestModule, :fun, 0, 2)
      expect(TestModule, :fun, 1, 2)

      Task.await_many([
        Task.async(fn ->
          TestModule.fun()
          TestModule.fun(:ok)
        end),
        Task.async(fn ->
          TestModule.fun(:ok)
          TestModule.fun()
        end)
      ])
    end
  end

  describe "verify/1" do
    test "raises when function is not called" do
      test = self()
      expect(TestModule, :fun, 0)

      assert_raise ExUnit.AssertionError, fn ->
        verify(test)
      end
    end

    test "raises when function is called too infrequently" do
      test = self()
      expect(TestModule, :fun, 0, 2)

      assert_raise ExUnit.AssertionError, fn ->
        TestModule.fun()
        verify(test)
      end
    end

    test "raises when function is called too often" do
      test = self()
      expect(TestModule, :fun, 0, 1)

      assert_raise ExUnit.AssertionError, fn ->
        TestModule.fun()
        TestModule.fun()

        verify(test)
      end
    end

    test "does not raise when no expectations are defined" do
      TestModule.fun()
      verify(self())
    end
  end
end
