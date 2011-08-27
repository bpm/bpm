require 'bpm/cli/base'
require 'open3'

module SpecHelpers
  attr_reader :stdin, :stdout, :stderr

  def bpm(*argv)
    opts = Hash === argv.last ? argv.pop : {}

    kill!
    create_pipes

    Open3.popen3(env, ["./bin/bpm", *argv]) do |stdin, stdout, stderr, thread|
      @stdin_child = stdin
      @stdout_child = stdout
      @stderr_child = stderr
    end

    if ENV['DEBUG_CLI']
      puts @stdout_child.read
      puts @stderr_child.read
      @stdout_child.rewind
      @stderr_child.rewind
    end
  end

  def out_until_block(io = stdout)
    # read 1 first so we wait until the process is done processing the last write
    chars  = io.read(1)

    loop do
      chars << io.read_nonblock(1000)
      sleep 0.05
    end
  rescue Errno::EAGAIN, EOFError
    chars
  end

  def input(line, opts = {})
    if on = opts[:on]
      should_block_on on
    end
    stdin << "#{line}\n"
  end

  def wait
    return unless @pid

    pid, status = Process.wait2(@pid, 0)

    @exit_status = status
    @pid = nil
  end

  def exit_status
    wait
    @exit_status
  end

  def kill!
    Process.kill(9, @pid) if @pid
  end

  def create_pipes
    @stdout, @stdout_child = IO.pipe
    @stdin_child, @stdin   = IO.pipe
    @stderr, @stderr_child = IO.pipe
  end

  def write_api_key(api_key)
    write_creds("user@example.com", api_key)
  end

  def write_creds(email, api_key)
    FileUtils.mkdir_p(bpm_dir)
    File.open(bpm_dir("credentials"), "w") do |file|
      file.write YAML.dump(:bpm_api_key => api_key, :bpm_email => email)
    end
  end
end

