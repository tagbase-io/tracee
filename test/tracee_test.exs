defmodule TraceeTest do
  use ExUnit.Case

  defmodule TestModule do
    @moduledoc false
    def arity_0, do: :ok
    def arity_1(_arg), do: :ok
  end

  test "expect/4 ensures function is called" do
    Tracee.expect(TestModule, :arity_0, 0)
    Tracee.expect(TestModule, :arity_1, 1, 2)

    assert TestModule.arity_0() == :ok
    assert TestModule.arity_1(:ok) == :ok
    assert TestModule.arity_1(:ok) == :ok

    Tracee.verify(self())
  end
end
