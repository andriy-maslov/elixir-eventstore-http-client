# EventStore  Client

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

__NOTE__ All arguments labeled `subscription` can be either a `%Subscription{}` struct
or a `{stream_name, subscription_group_name}` tuple.

```elixir
# Creating a subscription
{:ok, %EventStore.Subscriptions{} = subscription} =
    EventStore.create_subscription(client, subscription)
# Or if the subscription already exists, it returns:
# {:error, {:conflict, nil}}

# Note however, that the subscription struct is not "loaded" with the sub information.
# Subscription info includes statistics, configuration, pointer positions, etc.
# See the %Subscription{} module for full list of fields.
# If you want to load the server's data on the subscription you can use:
{:ok, subscription} = EventStore.load_subscription(client, subscription)
# which will return the following if the subscription is not found on the server:
# {:error, :not_found}

# Deleting a subscription is what you'd expect:
:ok = EventStore.delete_subscription(client, subscription)
# which can also return:
# {:error, :not_found}
# or:
# {:error, {:unexpected_status_code, code}}
```

A better way to create a subscription is using the `ensure_subscription` function.
The arguments are just like `create_subscription` but it will create a subscription
if needed, load the full subscription struct from the server and diff it with the
subscription argument. If the configuration differs, a conflict error is returned,
but if the desired configuration and the server one matches, a regular ok response
is returned.

```elixir
stream = "my-stream"
group = "my-stream-subscription"
# Create our custom config (unset fields will fall back to server defaults on creation)
config = %EventStore.Subscription.Config{bufferSize: 100}
# Using the above config we create our desired subscription
new_sub = EventStore.Subscription.new(stream, group, config)
# and we ensure that the subscription exists:
{:ok, subscription} = EventStore.ensure_subscription(client, new_sub)
# The `subscription` variable now contains a loaded Subscription struct.
```
This is the recommended way to create subscriptions.


To consume events from subscriptions:

```elixir
# Assuming `sub` is a subscription:
{:ok, ^sub, events} = EventStore.read_from_subscription(pid, sub, count: 1)
# `events` will be a list of 0 to `count` %EventStore.Event{} structs.
# The function can also return
# {:error, {:unexpected_status_code, code}}
```
