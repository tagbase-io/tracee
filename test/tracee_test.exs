defmodule TraceeTest do
  use ExUnit.Case

  test "start_link/0" do
    assert Tracee.start_link() == :ignore
  end
end
