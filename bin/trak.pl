#!/usr/bin/env perl

# Language features
use v5.24;
use strictures 2;
use feature qw(signatures);
no warnings qw(experimental::signatures);

# Everything else
use lib './lib';
use Term::UI;
use Term::ReadLine;
use Getopt::Long;
use Pod::Usage;
use Trak::Calc;

# Parse CLI options
GetOptions(
    'debug|d' => \my $debug,
    'help|h'  => \my $help,
) or die pod2usage(2);
my @formulas = @ARGV;

# Do nothing else if help was asked for
pod2usage(0) if $help;

# Calculate the formulas given, or drop into interactive mode
my $calc = Trak::Calc->new( debug => $debug );
if( scalar @formulas > 0 ) {
    say "'$_' evaluates to ", $calc->calculate($_) foreach @formulas;
}
else {
    do_interactive( $calc );
}

say "All done! Goodbye.";
exit 0;

# Give users an interactive session
sub do_interactive( $calc ) {
    my $term = Term::ReadLine->new('Trak');

    say qq{
Hi there! I'm a simple wrapper around Trak::Calc. My purpose in life
is to make it easy to enter one or more formulas to evaluate into
the calculator and evaluate the result. If there's a problem with
your formula, I will tell you that too. So let's get started!
    };

    my $input;
    do {
        # TODO: toggle debugging
        # TODO: handle empty input
        # TODO: help
        $input = $term->get_reply( prompt => "Enter a formula, or 'exit' to finish" );
        if( $input ne "exit" ) {
            say "'$input' evaluates to ", $calc->calculate( $input );
        }
    } while( $input ne "exit" );
}

__END__

=head1 NAME

bin/trak.pl - Run the IssueTrak formula parser

=head1 SYNOPSIS

    ./bin/trak.pl [--debug] [--help] [formula]

=head1 OPTIONS

=over 4

=item debug

Turn on debugging. This adds a lot of information to the display when the 
forumla parser is running.

=item help

Show the help information.

=item formula

One or more formulas, wrapped in quotations. One formula per quotation.

=back

=head1 DESCRIPTION

This program tries to parse any formulas passed through the command line 
directly. If no formulas were given, launch an interactive shell that lets
the user enter a formula and execute it immediately.

The calculator is implemented by L< Trak::Calc >. See the documentation there
for specifics on how it is implemented.

=head1 AUTHOR

Jason A. Crome C< jason@crome-plated.com >

=cut
