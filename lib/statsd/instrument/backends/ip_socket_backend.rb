require 'monitor'

module StatsD::Instrument::Backends
  class IPSocketBackend < StatsD::Instrument::Backend

    DEFAULT_IMPLEMENTATION = :statsd
    DEFAULT_PROTOCOL = :udp

    include MonitorMixin

    attr_reader :host, :port, :protocol
    attr_accessor :implementation

    # @param server [String,nil] Connection string in the form of "<host>:<port>"
    # @param implementation [Symbol,nil] Implementation to use, `:statsd` (default), `:datadog`, or `:statsite`
    # @param protocol [Symbol,nil] Protocol to use, `:udp` (default) or `:tcp`
    def initialize(server = nil, implementation = nil, protocol = nil)
      super()
      self.server = server || "localhost:8125"
      self.implementation = (implementation || DEFAULT_IMPLEMENTATION).to_sym
      self.protocol = (protocol || DEFAULT_PROTOCOL).to_sym
    end

    # @param metric [StatsD::Instrument::Metric]
    # @return [void]
    def collect_metric(metric)
      unless implementation_supports_metric_type?(metric.type)
        StatsD.logger.warn("[StatsD] Metric type #{metric.type.inspect} not supported on #{implementation} implementation.")
        return false
      end

      if metric.sample_rate < 1.0 && rand > metric.sample_rate
        return false
      end

      write_packet(generate_packet(metric))
    end

    # @param type [Symbol] Type of metric to check
    # @return [Boolean]
    def implementation_supports_metric_type?(type)
      case type
        when :h;  implementation == :datadog
        when :kv; implementation == :statsite
        else true
      end
    end

    # @param connection_string [String] Connection string in the form of "<host>:<port>"
    def server=(connection_string)
      self.host, port = connection_string.split(':', 2)
      self.port = port.to_i
      invalidate_socket
    end

    # @param host [String] Host to set
    def host=(host)
      @host = host
      invalidate_socket
    end

    # @param port [String] Port to set
    def port=(port)
      @port = port
      invalidate_socket
    end

    # @param protocol [Symbol] Protocol to set, `:udp` or `:tcp`
    def protocol=(protocol)
      @protocol = protocol
      invalidate_socket
    end

    def socket
      if @socket.nil?
        case protocol
        when :udp
          @socket = UDPSocket.new
          @socket.connect(host, port)
        when :tcp
          @socket = TCPSocket.new(host, port)
        else
          raise "Unsupported protocol #{protocol}, must be :udp or :tcp"
        end
      end
      @socket
    end

    # @param metric [StatsD::Instrument::Metric]
    def generate_packet(metric)
      command = "#{metric.name}:#{metric.value}|#{metric.type}"
      command << "|@#{metric.sample_rate}" if metric.sample_rate < 1 || (implementation == :statsite && metric.sample_rate > 1)
      if metric.tags
        if tags_supported?
          command << "|##{metric.tags.join(',')}"
        else
          StatsD.logger.warn("[StatsD] Tags are only supported on Datadog implementation.")
        end
      end

      command << "\n" if implementation == :statsite
      command
    end

    def tags_supported?
      implementation == :datadog
    end

    def write_packet(command)
      synchronize do
        socket.send(command, 0) > 0
      end
    rescue ThreadError => e
      # In cases where a TERM or KILL signal has been sent, and we send stats as
      # part of a signal handler, locks cannot be acquired, so we do our best
      # to try and send the command without a lock.
      socket.send(command, 0) > 0
    rescue SocketError, IOError, SystemCallError, Errno::ECONNREFUSED => e
      StatsD.logger.error "[StatsD] #{e.class.name}: #{e.message}"
    end

    def invalidate_socket
      @socket = nil
    end
  end
end
