defmodule EventStore.Behaviour do

  @doc """
    Ping EventStore. Return {:ok, 200} on 200 OK, {:error, reason} otherwise
  """
  @callback ping(client :: pid, options :: Keyword.t) ::
    {:ok, 200} |
    {:error, status :: integer} |
    {:error, reason :: term}


  @doc """
    write_events write [%EventStore.Event{}] to storage
  """
  @callback write_events(client :: pid, stream :: String.t, events :: [%EventStore.Event{}]) ::
    {:ok, events :: [%EventStore.Event{}]} |
    {:error, reason :: any} # TODO specify what errors exist

  @doc """
    Delete a stream.
    Options:
      hard_delete: true
  """
  @callback delete_stream(client :: pid, stream :: String.t, options :: Keyword.t) ::
    :ok |
    {:error, reason :: any}

  @doc """
    Generate a new valid event id
  """
  @callback gen_id!() :: String.t

  @doc """
    Read a stream given a specific offset (anchor), direction and size
  """
  @callback read_stream(client :: pid, stream :: String.t, movement :: tuple) ::
    {:ok, response :: %EventStore.Response{}} |
    {:error, reason :: any}

  @doc """
    Follow a stream from start to head (multiple calls required)
  """
  @callback follow_stream(client :: pid, stream :: String.t) ::
    {:ok, %EventStore.Response{}} |
    {:error, reason :: any}
  @callback follow_stream(client :: pid, response :: %EventStore.Response{}) ::
    {:ok, %EventStore.Response{}} |
    {:error, reason :: any}


  @doc """
    Create a new subscription.
  """
  @callback create_subscription(client :: pid, subscription :: %EventStore.Subscription{}) ::
    {:ok, %EventStore.Subscription{}} |
    {:error, {:conflict, nil}} |
    {:error, {:unexpected_status_code, code :: integer}}

  @doc """
    Ensure a subscription exists.
    Assert that configuration matches any existing subscription
  """
  @callback ensure_subscription(client :: pid, subscription :: %EventStore.Subscription{}) ::
    {:ok, %EventStore.Subscription{}} |
    {:error, :not_found} |
    {:error, {:conflict, {:conflicting_keys, keys :: [atom]}}} |
    {:error, {:unexpected_status_code, code :: integer}}

  @doc """
    Delete an existing Subscription
  """
  @callback delete_subscription(client :: pid, subscription :: %EventStore.Subscription{}) ::
  :ok |
  {:error, :not_found} |
  {:error, {:unexpected_status_code, code :: integer}}

  @doc """
    Load /info subscription
  """
  @callback load_subscription(client :: pid, subscription :: %EventStore.Subscription{}) ::
  {:ok, subscription :: %EventStore.Subscription{}} |
  {:error, :not_found} |
  {:error, {:unexpected_status_code, code :: integer}}
  @doc """
    Read from a subscription.
    Options:
      count: 1
  """
  @callback read_from_subscription(client :: pid, subscription :: %EventStore.Subscription{}, opts :: Keyword.t) ::
    {:ok, %EventStore.Subscription{}, [%EventStore.Event{}]} |
    {:error, reason :: any}

  @doc """
    Ack an ackable event
  """
  @callback ack_event(event :: %EventStore.Event{}) ::
    {:ok, nil} |
    {:error, reason :: any}

  @doc """
    Nack a nackable event
  """
  @callback nack_event(event :: %EventStore.Event{}) ::
    {:ok, nil} |
    {:error, reason :: any}

end
