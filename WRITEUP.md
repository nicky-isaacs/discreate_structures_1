Writeup
=======

My approach to this problem was to implement the pollard-rho
algorithm to find prime factors of a number. I did this in Jruby because
of its threading support, as there was a trivial way to factor many of the numbers on the test list which
could be done in a multi-threaded fashion, by saving previously calculated values and retrying them on other
numbers.

- what is the biggest number you managed to factor within 5 minutes?
  > 100000
- what is the smallest number you failed to factor within 5 minutes?
  > None
