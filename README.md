# Tracee

[![Hex.pm](https://img.shields.io/hexpm/v/tracee.svg?style=flat-square)](https://hex.pm/packages/tracee)
![CI Status](https://img.shields.io/github/actions/workflow/status/tagbase-io/tracee/test.yml?branch=main&style=flat-square)

This Elixir library offers functionality to trace and assert expected function
calls within concurrent Elixir processes.

This allows you to ensure that destructive and/or expensive functions are only
called the expected number of times. For more information, see [the Elixir forum
post](https://elixirforum.com/t/tracing-and-asserting-function-calls/63035) that
motivated the development of this library.

## Installation

Just add `tracee` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tracee, "~> 0.1", only: :test}
  ]
end
```

## Usage

```elixir
defmodule ModuleTest do
  use ExUnit.Case

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

    test "never calls expensive function" do
      expect(AnotherModule, :expensive_fun, 1, 0)

      assert Module.fun()
    end
  end
end
```

## License

[MIT](./LICENSE)
