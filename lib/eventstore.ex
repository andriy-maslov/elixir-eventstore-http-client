defmodule EventStore do
  @behaviour EventStore.Behaviour
  require Logger
  use GenServer
  alias HTTPoison.Response
  #alias EventStore.Event
  alias EventStore.Subscription

  @uuid UUID
  @json Poison

  @mime_json "application/json"
  @mime_events_json "application/vnd.eventstore.events+json"
  @mime_competingatom_json "application/vnd.eventstore.competingatom+json"

  @default_args [
    username: "admin",
    password: "changeit",
    port: 2113,
    host: nil,
    protocol: "http"
  ]

  #
  # GenServer basics
  #

  def start_link(args, opts \\ []) when is_list(args) do
    if args[:host] == nil do
      raise "host not set"
    end
    GenServer.start_link __MODULE__, args, opts
  end

  def init(args) when is_list(args) do
    {:ok, Keyword.merge(@default_args, args)}
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  #
  # EventStore behaviour
  #

  def gen_id! do
    @uuid.uuid4()
  end

  def ping(pid, options \\ []) do
    config = get_config(pid)
    case HTTPoison.get("#{base_url(config)}/ping", [], options) do
      {:ok, %Response{status_code: 200}} ->
        {:ok, {:status_code, 200}}
      {:ok, %Response{status_code: code}} ->
        {:error, {:status_code, code}}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, {:request, reason}}
    end
  end

  @doc """
    Write events to a stream.
    `stream` is the stream name, and
    `events` is a [Eventstore.Event{}]
  """
  def write_events(pid, stream, events) when is_binary(stream) and is_list(events) do
    config = get_config(pid)
    cleaned = events_to_writeable(events)
    payload = @json.encode!(cleaned)
    headers = get_headers(config)
    url = stream_url(config, stream)
    case HTTPoison.post!(url, payload, headers) do
      %Response{status_code: 201} ->
        {:ok, events}
      %Response{status_code: code} ->
        Logger.warn "Unexpected status code #{code} doing POST #{url} with payload: #{payload}"
        {:error, {:unexpected_status_code, code}}
    end
  end

  def delete_stream(pid, stream, options \\ []) when is_binary(stream) do
    config = get_config(pid)
    url = stream_url(config, stream)

    headers = get_headers(config)

    # options to headers
    headers = Enum.reduce options, headers, fn (opt, acc) ->
      case opt do
        {:hard_delete, true} -> [{"ES-HardDelete", "true"} | acc]
        _ -> acc
      end
    end

    case HTTPoison.delete!(url, headers) do
      %Response{status_code: 204} ->
        :ok
      %Response{status_code: code} ->
        Logger.warn "Unexpected status code #{code} doing DELETE #{url}"
        {:error, {:unexpected_status_code, code}}
    end
  end

  def read_from_stream(pid, stream, movement \\ {"head", "backward", 20}) when is_binary(stream) do
    config = get_config(pid)
    headers = get_headers(config)
    perform_read_stream_request(stream_url(config, stream, movement), headers)
  end

  def follow_stream(pid, stream) when is_binary(stream) do
    config = get_config(pid)
    headers = get_headers(config)
    movement = {0, "forward", 20}
    perform_read_stream_request(stream_url(config, stream, movement), headers)
  end
  def follow_stream(pid, %EventStore.Response{} = response) do
    config = get_config(pid)
    headers = get_headers(config)
    case EventStore.Response.get_link(response, "previous") do
      nil -> {:error, nil}
      url -> perform_read_stream_request(url, headers)
    end
  end

  @doc """
    Create a subscription
  """
  def create_subscription(pid, {stream, name}),
    do: create_subscription(pid, Subscription.new(stream, name))
  def create_subscription(pid, %Subscription{} = subscription) do
    config = get_config(pid)
    url = subscription_url(config, subscription)
    headers = get_headers(config, accept: @mime_json, content_type: @mime_json)
    case HTTPoison.put!(url, @json.encode!(subscription.config), headers) do
      %Response{status_code: 201}  -> {:ok, subscription}
      %Response{status_code: 409}  -> {:error, {:conflict, nil}}
      %Response{status_code: code} -> {:error, {:unexpected_status_code, code}}
    end
  end

  @doc """
    Will try to create subscription, if conflict, load existing and check that
    the existing configuration is like the one given
  """
  def ensure_subscription(pid, {stream, name}),
    do: ensure_subscription(pid, Subscription.new(stream, name))
  def ensure_subscription(pid, %Subscription{} = subscription) do
    # try to create:
    case create_subscription(pid, subscription) do
      {:ok, sub} -> # if OK, return loaded sub
        load_subscription(pid, sub)
      {:error, {:conflict, nil}} -> # if conflict
        {:ok, sub} = load_subscription(pid, subscription) # load existing
        case EventStore.Subscription.Config.diff(subscription.config, sub.config) do
          []    -> {:ok, sub} # No config difference, just return existing
          diff  -> {:error, {:conflict, {:conflicting_keys, diff}}} # conflict!
        end
      {:error, reason} -> # on any other error, parse reason through
        {:error, reason}
    end
  end
  def load_subscription(pid, {stream, name}),
    do: load_subscription(pid, Subscription.new(stream, name))
  def load_subscription(pid, %Subscription{} = subscription) do
    config = get_config(pid)
    url = "#{subscription_url(config, subscription)}/info"
    headers = get_headers(config, accept: @mime_json)
    case HTTPoison.get!(url, headers) do
      %Response{status_code: 200, body: body}  -> {:ok, EventStore.Subscription.parse(body)}
      %Response{status_code: 404}  -> {:error, :not_found}
      %Response{status_code: code} -> {:error, {:unexpected_status_code, code}}
    end
  end

  def delete_subscription(pid, {stream, name}),
    do: delete_subscription(pid, Subscription.new(stream, name))
  def delete_subscription(pid, subscription) do
    config = get_config(pid)
    url = subscription_url(config, subscription)
    headers = get_headers(config, content_type: nil, accept: @mime_json)
    case HTTPoison.delete!(url, headers) do
      %Response{status_code: 200}  -> :ok
      %Response{status_code: 404}  -> {:error, :not_found}
      %Response{status_code: code} -> {:error, {:unexpected_status_code, code}}
    end
  end

  @doc """
    Read events from subscription.
    Options:
      count: 1
  """
  def read_from_subscription(pid, %Subscription{} = subscription, opts \\ []) do
    config = get_config(pid)
    url = case Keyword.get(opts, :count) do
      nil -> subscription_url(config, subscription)
      c   -> "#{subscription_url(config, subscription)}/#{c}"
    end
    headers = get_headers(config, accept: @mime_competingatom_json)
    case perform_read_stream_request(url, headers) do
      {:ok, resp}      -> {:ok, subscription, resp.entries}
      {:error, reason} -> {:error, reason}
    end
  end

  def ack_events(pid, subscription, events) when is_list(events) do
    config = get_config(pid)
    url = "#{subscription_url(config, subscription)}/ack"
    params = [ids: Enum.join(Enum.map(events, &(&1.eventId)), ",")]
    headers = get_headers(config, accept: @mime_json, content_type: @mime_json)
    case HTTPoison.post!(url, "", headers, params: params) do
      %Response{status_code: 202} -> :ok
      %Response{status_code: code} -> {:error, {:unexpected_status_code, code}}
    end
  end

  def nack_events(pid, subscription, events, action \\ "Retry") when is_list(events) do
    config = get_config(pid)
    url = "#{subscription_url(config, subscription)}/nack"
    params = [ids: Enum.join(Enum.map(events, &(&1.eventId)), ","), action: action]
    headers = get_headers(config, accept: @mime_json, content_type: @mime_json)
    case HTTPoison.post!(url, "", headers, params: params) do
      %Response{status_code: 202} -> :ok
      %Response{status_code: code} -> {:error, {:unexpected_status_code, code}}
    end
  end


  #
  # Helpers
  #
  defp perform_read_stream_request(url, headers) do
    params = [embed: "body"]
    case HTTPoison.get!(url, headers, params: params) do
      %Response{status_code: 200, body: body} ->
        {:ok, EventStore.Response.parse(body)}
      %Response{status_code: code} ->
        {:error, {:unexpected_status_code, code}}
    end
  end

  defp get_headers(config, opts \\ []) do
    auth = Base.encode64("#{config[:username]}:#{config[:password]}")
    [{"Content-Type", Keyword.get(opts, :content_type, @mime_events_json)},
     {"Accept", Keyword.get(opts, :accept, @mime_events_json)},
     {"Authorization", "Basic #{auth}"}]
  end

  defp base_url(config) do
    "#{config[:protocol]}://#{config[:host]}:#{config[:port]}"
  end

  defp stream_url(config, stream) do
    "#{base_url(config)}/streams/#{stream}"
  end
  defp stream_url(config, stream, {anchor, direction, size}) do
    "#{stream_url(config, stream)}/#{anchor}/#{direction}/#{size}"
  end

  defp subscription_url(config, %EventStore.Subscription{eventStreamId: stream, groupName: name}) do
    "#{base_url(config)}/subscriptions/#{stream}/#{name}"
  end

  defp events_to_writeable(events) do
    Enum.map events, &Map.take(&1, [:eventId, :eventType, :data, :metadata])
  end

  defp get_config(pid) do
    GenServer.call(pid, :get_config)
  end



  #
  # GenServer callbacks
  #

  def handle_call(:get_config, _from, state) do
    {:reply, state, state}
  end
end


#
# /streams/<stream>/0/forward/<size>
#
#
