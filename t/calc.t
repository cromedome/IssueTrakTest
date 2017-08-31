#!/usr/bin/env perl

use lib './lib';
use v5.24;
use Test::Most;
use Test::Output;
use Trak::Calc;

# Create a calculator for the rest of our tests
my $calc = Trak::Calc->new;

# Formula complexity
cmp_ok( $calc->calculate( "1 + 2 + 3 + 4 - 5" ), '==', 5, 
    "Calculator can evaluate simple formulas" );
cmp_ok( $calc->calculate( "(1 + 2 ** 3 ) / 3 - ( 4 - 5)" ), '==', 4, 
    "...and complex ones too" );

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
 
# Valid numbers
lives_ok { $calc->calculate( "1 + 2" ) } "Calculator only works correctly with integers";
throws_ok { $calc->calculate( " 1.0 + 2.5 " ) } 
    qr/isn't an integer/,
    "...and complains when operands are not";

# Negative numbers
cmp_ok( $calc->calculate( "1 - -1" ), '==', 2, 
    "...it handles negative numbers properly" );
cmp_ok( $calc->calculate( "   8     /4   +   6 / ( 4-    2   )       " ), '==', 5, 
    "...and weird combinations of whitespace too" );

# Test parens
lives_ok { $calc->calculate( "(1 + 2) / (7 - 4)" ) } "Calculator correctly evaluates parenthesis";
throws_ok { $calc->calculate( "(1 + 2) / (7 - 4" ) } 
    qr/'\)' expected/,
    "...and complains when the closing paren is missing";
throws_ok { $calc->calculate( "(1 + 2) / (7 - 4))" ) } 
    qr/Unknown token: \)/,
    "...and thinks an unmatched ) is rightfully a problem";

# Invalid functions
throws_ok { $calc->calculate( "foo(2)" ) } 
    qr/Unknown function: 'foo'/,
    "Calculator won't try to evaluate functions it doesn't know about";

# Garbage at end
throws_ok { $calc->calculate( "(1 + 2) / (7 - 4) &^" ) } 
    qr/Unknown token/,
    "...and will complain when given invalid characters";

# Broken formula
throws_ok { $calc->calculate( "3 * - 1" ) } 
    qr/Parse error: too many operators, not enough operands/,
    "...and will fail when given an invalid formula";


# Look at calculator output
sub capture_calc_output {
    $calc->calculate( "1+1" );
}

# Make sure debugging output is generated when we want it
$calc->debug( 1 );
ok( $calc->debug, "...when we enable debugging for calculator" );

stderr_like( \&capture_calc_output,
    qr/Token Number Stack/,
    '...we get trace information on STDERR' );

# Help!
stdout_like { print $calc->help } 
    qr/The following operators/,
    "Calculator produces formula help when asked";

done_testing;

