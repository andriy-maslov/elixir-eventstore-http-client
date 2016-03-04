defmodule EventStoreWriteTest do
  @moduletag [:external, :write]

  alias EventStore.Event
  use ExUnit.Case
  doctest EventStore

  @opts Application.get_env :eventstore, :options

  setup_all do
    {:ok, pid} = EventStore.start_link @opts
    streams = %{
      write_no_data_no_metadata: UUID.uuid4(),
      write_data: UUID.uuid4(),
      write_many: UUID.uuid4(),
    }

    # Cleanip the stream ids
    on_exit fn ->
      {:ok, pid} = EventStore.start_link @opts
      Enum.each streams, fn({_, id}) ->
        EventStore.delete_stream(pid, id, hard_delete: true)
      end
    end

    {:ok, [
      streams: streams,
      pid: pid
    ]}
  end

  test "write event (no data, no metadata)", context do
    pid = context[:pid]
    stream = context[:streams][:write_no_data_no_metadata]

    event = Event.new("MyEvent")
    {:ok, [^event]} = EventStore.write_events(pid, stream, [event])
    # reading back all events from stream should yield one event
    {:ok, response} = EventStore.read_from_stream(pid, stream)

    assert length(response.entries) == 1
    entry = Enum.at(response.entries, 0)
    assert entry.eventType == event.eventType
    assert entry.eventId == event.eventId
    assert entry.isJson == false # no data, so no encoding
    assert entry.data == nil
    assert entry.metadata == nil
  end

  test "write event (no metadata)", context do
    pid = context[:pid]
    stream = context[:streams][:write_data]

    event = Event.new("MyEvent", %{"hello" => "world"})
    {:ok, [^event]} = EventStore.write_events(pid, stream, [event])
    # reading back all events from stream should yield one event
    {:ok, response} = EventStore.read_from_stream(pid, stream)

    assert length(response.entries) == 1
    entry = Enum.at(response.entries, 0)
    assert entry.eventType == event.eventType
    assert entry.eventId == event.eventId
    assert entry.isJson == true
    assert entry.data == %{"hello" => "world"}
    assert entry.metadata == nil
  end

  test "write many", context do
    pid = context[:pid]
    stream = context[:streams][:write_many]

    events = Enum.map 0..99, fn(n) ->
      Event.new("NumberAdded", %{"n" => n})
    end

    {:ok, _} = EventStore.write_events(pid, stream, events)
    {:ok, events} = get_events(pid, stream)

    # assert that we get same data out
    assert Enum.map events, &(&1.data["n"]) == 0..99
  end

  defp get_events(pid, response, events \\ []) do
    {:ok, new_response} = EventStore.follow_stream(pid, response)
    case length(new_response.entries) do
      0 -> {:ok, events}
      _ -> get_events(pid, new_response, Enum.concat([events, Enum.reverse(new_response.entries)]))
    end
  end

end
