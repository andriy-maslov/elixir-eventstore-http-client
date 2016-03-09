defmodule EventStore.Event do
  @derive [Poison.Encoder]

  defstruct [
    #:author,
    :data,
    :eventId,
    :eventNumber,
    :eventType,
    #:id,
    :isJson,
    :isLinkMetaData,
    :isMetaData,
    :links,
    :metadata,
    #:positionEventNumber,
    #:positionStreamId,
    :streamId,
    #:summary,
    #:title,
    :updated,
  ]

  @doc """
    Create a new Event. Takes a type as a String, and optional data and metadata


    With no data:
      iex> event = EventStore.Event.new("MyEvent")
      iex> event.eventType
      "MyEvent"
      iex> event.data
      nil

    With data:
      iex> event = EventStore.Event.new("MyEvent", %{"foo" => "bar"})
      iex> event.data
      %{"foo" => "bar"}
  """
  def new(type, data \\ nil, metadata \\ nil) do
    %EventStore.Event{
      eventId: EventStore.gen_id!(),
      eventType: type,
      data: data,
      metadata: metadata
    }
  end

  @doc """
    Return true if event is a new event (not read from database)

    iex> EventStore.Event.new?(%EventStore.Event{})
    true
    iex> EventStore.Event.new?(%EventStore.Event{eventNumber: 2})
    false
  """
  def new?(event) do
    event.eventNumber == nil
  end


  @doc """
    Get link by relation from event, or nil of no relation by that name

      iex> r = %EventStore.Event{
      ...>   links: [%{"uri" => "a", "relation" => "next"}]}
      iex> EventStore.Event.get_link(r, "next")
      "a"
      iex> EventStore.Event.get_link(r, "none")
      nil
  """
  def get_link(event, relation) do
    case Enum.find event.links, &(&1["relation"] == relation) do
      nil             -> nil
      %{"uri" => uri} -> uri
    end
  end
end
