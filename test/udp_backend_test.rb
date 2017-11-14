require 'test_helper'

class UDPBackendTest < Minitest::Test
  def setup
    StatsD.stubs(:backend).returns(@backend = StatsD::Instrument::Backends::UDPBackend.new)

    UDPSocket.stubs(:new).returns(@socket = mock('socket'))
  end

  def test_changing_host_or_port_should_create_new_socket
    @socket.expects(:connect).with('localhost', 1234).once
    @socket.expects(:connect).with('localhost', 2345).once
    @socket.expects(:connect).with('127.0.0.1', 2345).once

    @backend.server = "localhost:1234"
    @backend.socket

    @backend.port = 2345
    @backend.socket

    @backend.host = '127.0.0.1'
    @backend.socket
  end
end
