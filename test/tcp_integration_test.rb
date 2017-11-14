require 'test_helper'

class TCPIntegrationTest < Minitest::Test
  def setup
    @old_backend, StatsD.backend = StatsD.backend, StatsD::Instrument::Backends::TCPBackend.new("localhost:31798")
  end

  def teardown
    StatsD.backend = @old_backend
  end

  def test_live_local_tcp_socket
    thread = Thread.start do
      server = TCPServer.new('localhost', 31798)
      connection = server.accept
      message = connection.recvfrom(100).first
      connection.close
      server.close
      message
    end

    StatsD.increment('counter')
    assert_equal "counter:1|c", thread.value
  end
end
