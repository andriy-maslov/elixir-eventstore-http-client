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



end
