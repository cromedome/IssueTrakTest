#!/usr/bin/env perl

use lib './lib';
use v5.24;
use Test::Most;
use Test::Warn;
use Test::Output;
use Trak;

# Create a calculator for the rest of our tests
my $calc = Trak->new;

# Formula complexity
cmp_ok( $calc->calculate( "1 + 2 + 3 + 4 - 5" ), '==', 5, 
    "Calculator can evaluate simple formulas" );
cmp_ok( $calc->calculate( "(1 + 2 ^ 3 ) / 3 - ( 4 - 5)" ), '==', 4, 
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
warning_like { $calc->calculate( "5%(4/3)" ) } 
     qr/must be integer/,
    "...and the divisor must be an integer";
cmp_ok( $calc->calculate( "2 ^ 3" ), '==', 8, "...and can handle exponentiation" );
cmp_ok( $calc->calculate( "3 ^ 2 ^ 2" ), '==', 81, "...even several strung together" );

# Implicit multiplication
cmp_ok( $calc->calculate( "5(4+1)" ), '==', 25, '...as well as implicit multiplication' );
cmp_ok( $calc->calculate( "(3+2)(4+1)" ), '==', 25, '...in a couple of different fashions' );

# Functions
cmp_ok( $calc->calculate( "sqrt(9)" ), '==', 3, "Calculator calculates square root" );
throws_ok { $calc->calculate( "sqrt(-1)" ) }
    qr/can't take square root of a negative number/,
    "...but not the square root of negative numbers";
lives_ok{ $calc->calculate( "sin(90)" )} "...and sine";
lives_ok{ $calc->calculate( "cos(90)" )} "...and cosine";
lives_ok{ $calc->calculate( "tan(90)" )} "...and tangent";
lives_ok{ $calc->calculate( "pi()" )} "...and zero argument functions, like pi()";
lives_ok{ $calc->calculate( "sqrt( 8 + 1 )" ) } 
    "...and even evaluates simple expressions in argument lists";
 
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

throws_ok { $calc->calculate( "sqrt()" ) } 
    qr/Parse error: got \d arguments, expected \d/,
    "...and will fail when an argument is expected but not provided";

# Garbage at end
throws_ok { $calc->calculate( "(1 + 2) / (7 - 4) &^" ) } 
    qr/Unknown token/,
    "...and will complain when given invalid characters";

# Broken formulas
throws_ok { $calc->calculate( "3 * - 1" ) } 
    qr/Parse error: too many operators, not enough operands/,
    "...and will fail when given an invalid formula";

throws_ok { $calc->calculate( "3 ^ " ) } 
    qr/Parse error: too many operators, not enough operands/,
    "...and will fail when given too few operands";

# Bug related tests
cmp_ok( $calc->calculate(" 0 + 1 "), '==', 1, 
    'Bug where calculator failed when first operand was 0' );

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

