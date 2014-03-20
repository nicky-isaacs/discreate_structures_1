require 'fileutils'

Time.class_eval do
  def self.measure(&block)
    start = self.now
    yield
    self.now - start
  end
end

def primes_in_range(m=0, n)
  res=nil
  t = Time.measure do
    s = (m..n).to_a
    s[0] = s[1] = nil
    s.each do |p|
      next unless p
      break if p * p > n
      (p*p).step(n, p){ |m| s[m] = nil }
    end
    res = s.compact
  end
  puts "Took #{t} seconds for #{m} to #{n}\n"
  res
end

#  Borrowed from the ruby parallel gem => https://github.com/grosser/parallel/blob/master/lib/parallel.rb#L64
def processor_count
  @processor_count ||= begin
    os_name = RbConfig::CONFIG["target_os"]
    if os_name =~ /mingw|mswin/
      require 'win32ole'
      result = WIN32OLE.connect("winmgmts://").ExecQuery(
      "select NumberOfLogicalProcessors from Win32_Processor")
      result.to_enum.collect(&:NumberOfLogicalProcessors).reduce(:+)
    elsif File.readable?("/proc/cpuinfo")
      IO.read("/proc/cpuinfo").scan(/^processor/).size
    elsif File.executable?("/usr/bin/hwprefs")
      IO.popen("/usr/bin/hwprefs thread_count").read.to_i
    elsif File.executable?("/usr/sbin/psrinfo")
      IO.popen("/usr/sbin/psrinfo").read.scan(/^.*on-*line/).size
    elsif File.executable?("/usr/sbin/ioscan")
      IO.popen("/usr/sbin/ioscan -kC processor") do |out|
        out.read.scan(/^.*processor/).size
      end
    elsif File.executable?("/usr/sbin/pmcycles")
      IO.popen("/usr/sbin/pmcycles -m").read.count("\n")
    elsif File.executable?("/usr/sbin/lsdev")
      IO.popen("/usr/sbin/lsdev -Cc processor -S 1").read.count("\n")
    elsif File.executable?("/usr/sbin/sysconf") and os_name =~ /irix/i
      IO.popen("/usr/sbin/sysconf NPROC_ONLN").read.to_i
    elsif File.executable?("/usr/sbin/sysctl")
      IO.popen("/usr/sbin/sysctl -n hw.ncpu").read.to_i
    elsif File.executable?("/sbin/sysctl")
      IO.popen("/sbin/sysctl -n hw.ncpu").read.to_i
    else
      $stderr.puts "Unknown platform: " + RbConfig::CONFIG["target_os"]
      $stderr.puts "Assuming 1 processor."
      1
    end
  end
end

def chunk_size
  1000000
end

def threaded_primes_up_to(n)
  worker_threads=[]
  result=[]
  number_of_chunks = (n/chunk_size.to_f).floor
  @chunks_left_to_process = (0..number_of_chunks).to_a
  puts "There are #{number_of_chunks} chunks to process"
  mutex = Mutex.new
  worker_number = [processor_count, number_of_chunks].min

  worker_number.times do
    worker_threads << Thread.new do
      while true
        my_chunk_index=nil
        # Get a chunk atomically
        mutex.synchronize do
          Thread.exit if @chunks_left_to_process.empty?
          my_chunk_index = @chunks_left_to_process.pop
        end

        start = (my_chunk_index*chunk_size)
        finish = [start + chunk_size, n].min
        thread_results = primes_in_range(start, finish)

        # Report results atomically
        mutex.synchronize{ result.concat thread_results }
      end
    end
  end

  worker_threads.each{ |t| t.join }
  result
end

def load_primes_in_memory(n=1000)
  prime_path = File.join File.dirname(__FILE__), '.primes'

  if File.exists? prime_path
    prime_cache = File.open(prime_path, 'r').each_line.to_a.map{ |l| l.to_i }
    return if prime_cache.size > 0 and prime_cache.size >= n
  end

  puts "Caching list of primes, please hold"
  prime_cache = threaded_primes_up_to n
  @_prime_cache = prime_cache.sort_by{ |a| a }

  Thread.new do
    prime_str = prime_cache.inject(''){ |acc, n| acc + "#{n}\n" }
    FileUtils.rm prime_path
    File.open(prime_path, 'w+'){ |f| f << prime_str }
  end
end

def prime_cache
  @_prime_cache ? @_prime_cache : nil
end

def prime_cache=(n)
  @_prime_cache = n
end

#----------- Main -------------

file_name = ARGV.shift
file = File.open file_name, 'r'

input_numbers = file.each_line.to_a.map{ |line| line.to_i }
# load_primes_in_memory Math.sqrt(input_numbers.max).to_i
load_primes_in_memory Math.sqrt(input_numbers[1000]).to_i

input_numbers.each do |n|
  t = Time.measure do
    sqrt = Math.sqrt n
    prime_cache[0..sqrt].each do |prime|
      if n%prime == 0
        other_val = n/prime
        # next unless prime_cache.include?(other_val)
        ret_val = [prime, other_val]
        puts "\n\nFactors of #{n}: " + ret_val.inspect
        break
      end
    end
  end
  puts "Took  #{t} seconds"
end
