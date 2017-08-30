#!/usr/bin/env perl

use lib './lib';
use Test::Most;
use Trak::Calc;

# Create a calculator for the rest of our tests
my $calc = Trak::Calc->new;

# Invalid operators
# Invalid formulas
# Invalid functions
# Test parens
# Garbage at end

# Formula complexity
cmp_ok( $calc->calculate( "1 + 2 + 3 + 4 - 5" ), '==', 5, 
    "Calculator can evaluate simple formulas" );
#cmp_ok( $calc->calculate( "(1 + 2 ** 3 ) / 3 - ( 4 - 5)" ), '==', 4, 
    #"...and complex ones too" );

# Operator tests
cmp_ok( $calc->calculate( "1 + 2" ), '==', 3, "Calculator does basic addition" );
cmp_ok( $calc->calculate( "4 - 2" ), '==', 2, "...and subtraction" );
cmp_ok( $calc->calculate( "3 * 2" ), '==', 6, "...and multiplication" );
cmp_ok( $calc->calculate( "3 / 3" ), '==', 1, "...and division" );
throws_ok { $calc->calculate( "5/0" ) } 
     "/divide by zero/",
    "...but doesn't let us divide by zero";
cmp_ok( $calc->calculate( "7 % 4" ), '==', 3, "...we can do modulus too" );
throws_ok { $calc->calculate( "5%0" ) } 
     "/mod by zero/",
    "...but again, not by zero";
cmp_ok( $calc->calculate( "2 ** 3" ), '==', 8, "...and can handle exponentiation" );

 # Functions
cmp_ok( $calc->calculate( "sqrt(9)" ), '==', 3, "Calculator calculates square root" );
lives_ok{ $calc->calculate( "sin(90)" )} "...and sine";
lives_ok{ $calc->calculate( "cos(90)" )} "...and cosine";
lives_ok{ $calc->calculate( "tan(90)" )} "...and tangent";
 
# Negative numbers
cmp_ok( $calc->calculate( "1 - -1" ), '==', 2, 
    "Calculator handles negative numbers properly" );
#cmp_ok( $calc->calculate( "   8     /4   +   6 / ( 4-    2   )       " ), '==', 5, 
    #"...and weird combinations of whitespace" );

# Throw my other examples in here too...
done_testing;

