#Welcome

This is my solution to the prime breaking problem. My approach was as follows:

  1. In one thread, iterate over all the prime numbers from 2 - sqrt(N). Cache both results in a set as there were several repeated answers.
  2. In two more threads, iterate ascending and descending along the cached values in the set to see if any of the previos values matched
  3. Once one of the threads find an answer, kill the remaining threads

##Requirements

This code is built to run on Jruby, an abstraction of Java written in Ruby. Was chosen for threading support as the vanilla implementation of Ruby (MRI) has a global lock, only running a single thread at a time.

You will need:

- RVM (optional, but helpful to manage ruby versions)
- Jruby 1.7.10
- Java (1.6.0_65 tested)

##Running

Run with the following command:

```bash
  rvm use jruby-1.7.10
  ruby composite_list.txt
```

##Todo
- [ ] Get working RSA cracker
- [x] Get working prime number factorization
- [ ] Refactor to make prime number cracking haul ass
