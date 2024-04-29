defmodule Tracee.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Tracee,
      Tracee.Handler
    ]

    Supervisor.start_link(children, name: Tracee.Supervisor, strategy: :one_for_one)
  end
end
