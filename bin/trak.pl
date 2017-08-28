#!/usr/bin/env perl

use lib './lib';
use v5.24;
use strictures 2;
use Term::UI;
use Term::ReadLine;
use Trak::Calc;

my $term = Term::ReadLine->new('Trak');
say qq{
Hi there! I'm a simple wrapper around Trak::Calc. My purpose in life
is to make it easy to enter one or more formulas to evaluate into
the calculator and evaluate the result. If there's a problem with
your formula, I will tell you that too. So let's get started!
};

my $calc = Trak::Calc->new;
my $input;
do {
    $input = $term->get_reply( prompt => "Enter a formula, or 'exit' to finish" );
    if( $input ne "exit" ) {
        try {
            say $calc->calculate( $input );
        }
        catch {
            die $_;
        };
    }
} while( $input ne "exit" );

say "Ok. All done! Goodbye.";
exit 1;

