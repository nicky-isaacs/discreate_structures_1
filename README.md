#Welcome

This is my solution to the prime breaking problem. My approah was as follows:

  1. Thread out the generation of prime numbers from 2 to N-1, where N is the largest number we need to factor
  2. For each number we need to factor, iterate over the list of primes

##Requirements

This code is built to run on jRuby, an abstraction of Java written in Ruby. Was chosen for threading support and good memory management.

You will need:

- RVM (or other way to manage ruby versions)
- Jruby 1.7.10
- Java (1.6.0_65 tested)

##Running

Due to the memery needs of the prime number caching, this require a whole lotta space.
Run with the following command:

```bash
  rvm use jruby-1.7.10
  ruby -J-Xmx8192m main.rb composite_list.txt
```
