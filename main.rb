require 'fileutils'
require 'set'
# require 'debugger'

module TimeExtensions
  Time.class_eval do
    def self.measure(&block)
      start = self.now
      yield
      self.now - start
    end
  end
end

def rho(n)
  c  = srand
  x  = srand
  xx = x;

  return 2 if n % 2 == 0

  begin
    x  = ( ( ( x * x ) % n ) + c ) % n
    xx = ( ( ( xx * xx ) % n) + c ) % n
    xx = ( ( (xx * xx ) % n) + c) % n
    divisor = (x - xx).gcd n
  end while divisor == 1

  divisor
end

Numeric.class_eval do

  def prime_factors
    divisor = rho self
    [divisor, self/divisor]
  end

end

module ExtraCredit
  include TimeExtensions
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
    1000000000
  end

  def threaded_primes_up_to(n)
    worker_threads=[]
    result=[]
    number_of_chunks = (n/chunk_size.to_f).ceil
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

    puts "Loading list of primes into memory, please hold"
    prime_cache = threaded_primes_up_to(n).sort_by{ |a| a }
    puts "Primes loaded, sample: #{prime_cache[0..10].inject(''){ |acc, this| acc + "#{this}, " } }"

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

  def execute(file)
    file_buffer = File.open file, 'r'
    file_buffer.each_line.to_a.map{ |line| line.to_i }.each_slice(1000).to_a.each do |input_numbers|
      load_primes_in_memory Math.sqrt(input_numbers.max-1).to_i

      input_numbers.each do |n|
        t = Time.measure do
          ret_val=[]
          sqrt = Math.sqrt n
          prime_cache[0..sqrt].each do |prime|
            if n%prime == 0
              other_val = n/prime
              next unless prime_cache.include?(other_val)
              ret_val = [prime, other_val]
              # puts "\n\nFactors of #{n}: " + ret_val.inspect
              break
            end
          end
          raise "Missed #{n}!!" if ret_val.empty?
        end
        # puts "Took  #{t} seconds"
      end
    end

  end
end

module BasicAssignment
  include TimeExtensions
  @@seen_before = Set.new

  def is_prime?(n)
    return false if ( n%2==0 and n!=2 )

    square_root = (Math.sqrt n).ceil

    (2..square_root).each do |i|
      return false if (n%i==0)
    end

    true
  end

  def prime_factors(n)
    first_factor = rho n

    (2..n).each do |i|
      next unless is_prime? i
      return [i, (n/i)] if( n%i == 0 )
    end
  end

  def do_it(file)
    file_buffer = File.open file, 'r'
    mutex = Mutex.new

    file_buffer.each_line.map{ |l| l.to_i }.each_with_index do |number, index|
      t = Time.measure{ result = factor number }
      #puts "Factors of #{number} => #{result.inspect}\nTook #{t} seconds"
      puts "Took #{t} seconds for #{number.to_s.size} digit number"
      break if t > (300)
    end
  end

  def factor(number)
    result = nil
    t = Time.measure do
      t1 = Thread.new do
        q = @@seen_before.detect{ |i| number%i == 0 }
        mutex.synchronize{ result = [q, number/q] }
      end

      t2 = Thread.new do
        q = @@seen_before.reverse.detect{ |i| number%i == 0 }
        mutex.synchronize{ result = [q, number/q] }
      end

      t3 = Thread.new do
        r = number.prime_factors
        mutex.synchronize do
          result = r
          @@seen_before << result.first
          @@seen_before << result[-1]
        end
      end

      # Wait for one or the other to finish
      begin
        unless t1.status
          t2.kill
          t3.kill
        end

        unless t2.status
          t1.kill
          t3.kill
        end

        unless t3.status
          t1.kill
          t2.kill
        end
      end while (t1.status or t2.status or t3.status)

      unless result
        result = number.prime_factors
        @@seen_before << result.first
        @@seen_before << result[-1]
      end
    end
    result
  end
end

module RSACrack
  include BasicAssignment
  include ExtraCredit

  # message is an array of number strings, public key is an array [n, e]
  def decode(msg, public_key)
    r = []
    d = break_pub_key public_key
    n = public_key[0]

    msg.each do |line|
      line_int = line.to_i
      decoded_line = (line**d)%n
      puts decoded_line
      r << decoded_line
    end

    # Unicode to str
    str_arr = r.map{ |n| n.pack('U') }
    puts str_arr.inject{ |acc, s| acc + "#{s} " }
  end

  def break_pub_key(pub_key)
    n = pub_key[0]
    e = pub_key[1]

    # Needed to find
    p=q=k=v=d=nil;

    p, q = BasicAssignment.factor n
    k = (p-1) * (q-1)
    compute_private_key k, e
  end

  def compute_private_key(k,e)
    d,v,l = compute_GCD e, k

    if ( d < 0)
      m = (-d/k) + 1
      d = d + m * k
    end
    d
  end

  def compute_GCD(u,v)
    u1,u2,u3 = 1,0,u
    v1,v2,v3 = 0,1,v
    while (v3 > 0)
      q = u3/v3
      t1 = u1 - q * v1
      t2 = u2 - q * v2
      t3 = u3 - q * v3
      u1,u2,u3 = v1,v2,v3
      v1,v2,v3 = t1,t2,t3
    end
    [u1,u2,u3]
  end
end

#----------- Main -------------

include BasicAssignment
include ExtraCredit
include RSACrack

file_name = ARGV.shift

if ARGV.include? 'ec'
  ExtraCredit.execute file_name
elsif file_name == 'crack'
  # debugger
  msg_arr = File.read(ARGV.shift).each_line.map{ |a| a.to_i }
  pub_key = File.read(ARGV.shift).each_line.map{ |a| a.to_i }
  RSACrack.decode msg_arr, pub_key
else
  t = Time.measure{ BasicAssignment.do_it file_name }
  puts "\n\nWhole thing took #{t} seconds"
end
