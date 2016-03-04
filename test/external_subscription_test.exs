defmodule ExternalSubscriptionTest do
  @moduletag [:external]

  alias EventStore.Subscription
  alias EventStore.Event
  use ExUnit.Case

  @opts Application.get_env :eventstore, :options

  setup_all do
    {:ok, pid} = EventStore.start_link @opts
    stream = UUID.uuid4()

    # insert test events
    events = Enum.map 0..29, fn(n) ->
      Event.new!("FooBared", %{"n" => n})
    end
    {:ok, _} = EventStore.write_events(pid, stream, events)

    # Cleanip the stream
    on_exit fn ->
      {:ok, pid} = EventStore.start_link @opts
      :ok = EventStore.delete_stream(pid, stream, hard_delete: true)
    end

    {:ok, [
      stream: stream,
      pid: pid
    ]}
  end

  test "Create, load and delete subscription", context do
    pid = context[:pid]
    stream = context[:stream]
    {:ok, created_sub} = EventStore.create_subscription(pid, {stream, "my-sub"})
    assert %Subscription{} = created_sub
    {:ok, loaded_sub} = EventStore.load_subscription(pid, created_sub)
    assert %Subscription{} = loaded_sub

    # diff the config before and after
    diff = Subscription.Config.diff(created_sub.config, loaded_sub.config)
    assert diff == []
    # delete the subscription again
    assert EventStore.delete_subscription(pid, loaded_sub) == :ok
  end

end
