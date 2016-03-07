# EventStore

__NOTE__: This is very much a work-in-progress.
Only the things that I actually need is implemented, and I'm still not happy
with parts of the API, so expect changes.

## Things implemented

- Streams
    - Write events
    - Read events
    - Delete
- Subscription (competing consumers)
    - Create, info, delete
    - Read events

## Note that

- Requests are performed in the process that calls the `EventStore.*` API
- Events (entries) are returned in the same order as EventStore returns them.
  That is, the most recent event is at the top of the list. This might be
  counter-intuitive if traversing a stream from event 0 to head.

## Usage(ish)

Connecting a client

```elixir
{:ok, client} = EventStore.start_link host: "192.168.99.100"
# If this works, we have a connection
{:ok, _} = EventStore.ping client
```

Writing events

```elixir
# Create events
event_one = EventStore.Event.new("EventType1", %{"data" => "here"})
event_two = EventStore.Event.new("EventType2", %{"also" => "data"})
# Writing them to a stream:
events = [event_one, event_two]
{:ok, ^events} = EventStore.write_events(client, "stream-name", events)
```

Reading from a stream

```elixir
# Reading from a stream
{:ok, response} = EventStore.read_from_stream(client, "stream-name")
# response is an EventStore.Response struct
IO.inspect(response.entries) # this is the events read from the stream
```

```elixir
# You can control exactly what you read with the third argument:
movement = {"head", "backward", 20} # this is the default
# to read from the start of your stream:
movement = {0, "forward", 20} # which reads as: "Read from event 0 and forward 20 events"
# NOTE the order of the returned events is _always_ most recent event first
{:ok, response} = EventStore.read_from_stream(client, "stream-name", movement)
```

Reading a stream (from event 0 and forward)

```elixir
# If you want to traverse a stream from event 0 and forward, the follow_stream
# function might be more convenient. It takes either a stream name or a response struct.
# If a stream name is given, a read at event 0 and forward is performed.
# If a response is given, the events following that response will be read.
# (This done by following the `previous` links)
{:ok, first_response} = EventStore.follow_stream(client, "stream-name")
first_entries = Enum.reverse(first_response.entries) # Reverse to get oldest event at the top
{:ok, second_response} = EventStore.follow_stream(client, first_response)
second_entries = Enum.reverse(second_response.entries) # Reverse to get oldest event at the top

entries = Enum.concat([first_entries, second_entries])

# Read more here: http://docs.geteventstore.com/http-api/3.5.0/reading-streams/
```

### Subscriptions

TODO
