defmodule Tracee.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [%{id: Tracee, type: :worker, start: {Tracee, :start_link, []}}]
    Supervisor.start_link(children, name: Tracee.Supervisor, strategy: :one_for_one)
  end
end
