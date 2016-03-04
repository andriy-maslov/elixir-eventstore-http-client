defmodule EventStore do
  @behaviour EventStore.Behaviour
  require Logger
  use GenServer
  alias HTTPoison.Response
  alias EventStore.Event

  @uuid UUID
  @json Poison
  @mime_json_events "application/vnd.eventstore.events+json"

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

  def write_events(pid, stream, events) when is_binary(stream) and is_list(events) do
    config = get_config(pid)
    cleaned = events_to_writeable(events)
    payload = @json.encode!(cleaned)
    headers = get_default_headers()
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
    default_headers = []
    headers = Enum.reduce options, default_headers, fn (opt, acc) ->
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

  def read_stream(pid, stream, movement \\ {"head", "backward", 20}) when is_binary(stream) do
    config = get_config(pid)
    perform_read_stream_request(stream_url(config, stream, movement))
  end

  def follow_stream(pid, stream) when is_binary(stream) do
    config = get_config(pid)
    movement = {0, "forward", 20}
    perform_read_stream_request(stream_url(config, stream, movement))
  end
  def follow_stream(_pid, %EventStore.Response{} = response) do
    case EventStore.Response.get_link(response, "previous") do
      nil -> {:error, nil}
      url -> perform_read_stream_request(url)
    end
  end


  #
  # Helpers
  #
  defp perform_read_stream_request(url) do
    headers = get_default_headers()
    case HTTPoison.get!(url, headers, params: [embed: "body"]) do
      %Response{status_code: 200, body: body} ->
        {:ok, EventStore.Response.parse(body)}
      %Response{status_code: code} ->
        {:error, {:unexpected_status_code, code}}
    end
  end

  defp get_default_headers do
    [
      {"Content-Type", @mime_json_events},
      {"Accept", @mime_json_events}
    ]
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
