defmodule EventStore.Response do
  defmodule Link do
    defstruct [:uri, :relation]
  end

  @derive [Poison.Encoder]
  @json Poison

  defstruct [
    :id,           # stream id (uri)
    :headOfStream, # boolean, is response head of stream
    :streamId,     # Name of stream to read
    :eTag,         # etag of last response
    :links,        # A list of %{"uri", "relation"}
    :entries,      # A list of %Event{} structs
  ]

  @doc """
    Get link by relation from response, or nil of no relation by that name

      iex> r = %EventStore.Response{links: [%EventStore.Response.Link{uri: "a", relation: "next"}]}
      iex> EventStore.Response.get_link(r, "next")
      "a"
      iex> EventStore.Response.get_link(r, "none")
      nil
  """
  def get_link(response, relation) do
    case Enum.find response.links, &(&1.relation == relation) do
      nil             -> nil
      %Link{uri: uri} -> uri
    end
  end

  def parse(body) when is_binary(body) do
    response = @json.decode!(body, as: %EventStore.Response{
      entries: [%EventStore.Event{}],
      links: [%EventStore.Response.Link{}]
    })

    # decode entries' data if it is json
    entries = Enum.map response.entries, fn (%EventStore.Event{isJson: isJson} = entry) ->
      case isJson do
        true  -> %EventStore.Event{entry|data: @json.decode!(entry.data)}
        false -> entry
      end
    end

    %EventStore.Response{response|entries: entries}
  end
end
