defmodule EventStore.Subscription do
  @moduledoc """
  An EventStore subscription reference (competing consumers)
  """

  defmodule Link do
    defstruct [:href, :rel]
  end

  defmodule Config do
    alias EventStore.Subscription.Config
    @moduledoc """
      Options:
        :resolveLinktos               # Tells the subscription to resolve link events.
        :startFrom                    # Start the subscription from the position-th event in the stream.
        :extraStatistics              # Tells the backend to measure timings on the clients so statistics will contain histograms of them.
        :checkPointAfterMilliseconds  # The amount of time the system should try to checkpoint after.
        :liveBufferSize               # The size of the live buffer (in memory) before resorting to paging.
        :readBatchSize                # The size of the read batch when in paging mode.
        :bufferSize                   # The number of messages that should be buffered when in paging mode.
        :maxCheckPointCount           # The maximum number of messages not checkpointed before forcing a checkpoint.
        :maxRetryCount                # Sets the number of times a message should be retried before being considered a bad message.
        :maxSubscriberCount           # Sets the maximum number of allowed subscribers
        :messageTimeoutMilliseconds   # Sets the timeout for a client before the message will be retried.
        :minCheckPointCount           # The minimum number of messages to write a checkpoint for.
        :namedConsumerStrategy        # RoundRobin/DispatchToSingle

    See http://docs.geteventstore.com/http-api/3.5.0/competing-consumers/
    """
    defstruct [
      resolveLinktos: nil,
      startFrom: nil,
      messageTimeoutMilliseconds: nil,
      extraStatistics: nil,
      maxRetryCount: nil,
      liveBufferSize: nil,
      bufferSize: nil,
      readBatchSize: nil,
      preferRoundRobin: nil,
      checkPointAfterMilliseconds: nil,
      minCheckPointCount: nil,
      maxCheckPointCount: nil,
      maxSubscriberCount: nil,
      namedConsumerStrategy: nil,
    ]

    @doc """
    Compare two configs, returning a list of keys from c1 that != key in c2 and is not
    nil in c1

        iex> c1 = %Config{bufferSize: 200}
        iex> c2 = %Config{bufferSize: 100, maxRetryCount: 1}
        iex> Config.diff(c1, c2)
        [:bufferSize]
        iex> Config.diff(c2, c1)
        [:maxRetryCount, :bufferSize]
    """
    def diff(%Config{} = c1, %Config{} = c2) do
      Enum.reduce Map.keys(c1), [], fn(key, acc) ->
        case Map.fetch!(c1, key) do
          nil -> acc
          c1val -> if c1val != Map.fetch!(c2, key), do: [key | acc], else: acc
        end
      end
    end
  end

  @derive [Poison.Encoder]
  @json Poison


  defstruct [
    :links,
    :config,
    :eventStreamId,
    :groupName,
    :status,
    :averageItemsPerSecond,
    :parkedMessageUri,
    :getMessagesUri,
    :totalItemsProcessed,
    :countSinceLastMeasurement,
    :lastProcessedEventNumber,
    :lastKnownEventNumber,
    :readBufferCount,
    :liveBufferCount,
    :retryBufferCount,
    :totalInFlightMessages,
    :connections
  ]

  def parse(body) do
    @json.decode!(body, as: %EventStore.Subscription{
      config: %Config{},
      links: [%Link{}]
    })
  end

  def new(stream, group_name, config \\ %EventStore.Subscription.Config{}) do
    %EventStore.Subscription{
      eventStreamId: stream,
      groupName: group_name,
      config: config
    }
  end
end
