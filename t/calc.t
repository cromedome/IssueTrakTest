#!/usr/bin/env perl

use lib './lib';
use Test::Most;
use Trak::Calc;

# Create a calculator for the rest of our tests
my $calc = Trak::Calc->new;

# Invalid operators
# Invalid formulas
# Invalid functions
# Simple formula
# Complex formula/ops
# Test each op
# Test parens
# Garbage at end

# Catch divide by zero
throws_ok { $calc->calculate( "5/0" ) } 
     "/divide by zero/",
    '...and fails gracefully on division by zero';

throws_ok { $calc->calculate( "5%0" ) } 
     "/mod by zero/",
    '...and fails gracefully on modulus by zero';

done_testing;

