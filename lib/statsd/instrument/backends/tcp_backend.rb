module StatsD::Instrument::Backends
  class TCPBackend < StatsD::Instrument::Backends::IPSocketBackend
    # @param server [String,nil] Connection string in the form of "<host>:<port>"
    # @param implementation [Symbol,nil] Implementation to use, `:statsd` (default), `:datadog`, or `:statsite`
    def initialize(server = nil, implementation = nil)
      super(server, implementation, :tcp)
    end
  end
end
