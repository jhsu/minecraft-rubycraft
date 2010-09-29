#!/usr/bin/env ruby

require 'open3'
include Process

class MinecraftServer
  attr_accessor :ready, :player_count, :players

  @stdin
  @stdout
  @stderr

  def initialize(process)
    @players = []
    @player_count = 0
    @ready = false
    @stdin, @stdout, @stderr = Open3.popen3(process)
  end

  def puts(message)
    begin
      @stdin.puts message
    rescue Errno::EPIPE
      Kernel.puts "Stdin not responding, is server running?"
    end
  end

  def gets
    r,w,e = IO.select([@stderr, @stdin], nil, nil)
    output = ""
    unless r.nil?
      for i in (0..(r.length)) do
        unless r[i].nil?
          begin
            output << r[i].gets + "\n"
          rescue IOError => e
          end
        end
      end
    end
    output.chop.chop
  end

  def shutdown
    self.puts "stop"
    Process.kill("SIGHUP", 0)
  end

  def close
    @stdin.close
    @stdout.close
    @stderr.close
  end
end

@messages = {}
@server = MinecraftServer.new("java -Xmx1024M -Xms1024M -jar minecraft_server.jar nogui")

while line = @server.gets
  case line
  when /\[INFO\] Done!/
    @server.ready = true
    puts "Ready to accept commands"
  when /\[INFO\] (\w+) \[.*\] logged in/
    user = $1.downcase
    @server.puts "say players: #{@server.players.join(',')}"
    if @messages[user] && @messages[user].any?
      @messages[user].each {|msg| @server.puts "tell #{user} msg"}
    end
    @server.puts "list"
  when /\[INFO\] (\w+) lost connection/
    user = $1
    @server.players.delete(user.downcase)
  when /\[INFO\] Connected players: (.*)/
    players = $1.strip.downcase
    @server.players = players.split
  when /\[INFO\] <(\w+)> (\w+):\s?(.*)/
    from, to, msg = $1.downcase, $2.downcase, $3
    unless @server.players.include?(to.downcase)
      @messages[to] ||=[]
      @messages[to] << "#{from}: #{msg}"
      puts "queued #{from} message for #{to}"
    end
  when /\[INFO\] <(\w+)> (.*)/
    user = $1
    message = $2.strip
  when /\[INFO\] (\w+) issued server command: water/
    @server.puts "give #{$1} 8"
  end
  puts line
end
