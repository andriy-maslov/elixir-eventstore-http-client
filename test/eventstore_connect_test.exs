defmodule EventStoreConnectTest do
  @moduletag [:external]

  use ExUnit.Case
  doctest EventStore

  @opts Application.get_env :eventstore_client, :options

  test "start/stop" do
    # we don't connect on start_link, so a fake host is ok
    {:ok, pid} = EventStore.start_link host: "fake"
    assert is_pid(pid)
    :ok = EventStore.stop(pid)
  end

  test "ping" do
    {:ok, pid} = EventStore.start_link @opts
    {:ok, {:status_code, 200}} = EventStore.ping pid
  end
end
