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
use Try::Tiny;
use Trak;

# Parse CLI options
GetOptions(
    'debug|d'       => \my $debug,
    'help|h'        => \my $help,
    'formulahelp|f' => \my $fh,
) or die pod2usage(2);
my @formulas = @ARGV;

# Show help and exit if help was requested
pod2usage(0) if $help;

# Show help, calculate the formulas given, or drop into interactive mode
my $calc = Trak->new( debug => $debug );
if( $fh ) {
    say $calc->help;
}
elsif( scalar @formulas > 0 ) {
    say "'$_' evaluates to ", $calc->calculate($_) foreach @formulas;
}
else {
    do_interactive( $calc );
}

say "All done! Goodbye.";
exit 0;

##
## Give users an interactive session
##
sub do_interactive( $calc ) {
    my $term = Term::ReadLine->new('Trak');

    say qq{
Hi there! I'm a simple wrapper around Trak.pm. My purpose in life
is to make it easy to enter one or more formulas to evaluate into
the calculator and evaluate the result. If there's a problem with
your formula, I will tell you that too. So let's get started!

Commands available to you are help, debug, and exit.
    };

    say "Debugging is set to ", $calc->debug ? "true" : "false", ".\n";
    my $input;
    do {
        $input = $term->get_reply( prompt => "Enter a formula, or 'exit' to finish" );
        if( length $input ) {
            if( $input eq "debug" ) {
                $calc->debug( !$calc->debug );
                say "Debugging now set to ", $calc->debug ? "true." : "false.";
            }
            elsif( $input eq "help" ) {
                say $calc->help;
            }
            elsif( $input ne "exit" ) {
                try {
                    say "'$input' evaluates to ", $calc->calculate( $input );
                }
                catch {
                    say $_;
                };
            }
        }
        else {
            say "No formula entered.";
        }
    } while(( $input // '' ) ne "exit" );
}

__END__

=head1 NAME

bin/trak.pl - Run the IssueTrak formula parser

=head1 SYNOPSIS

    ./bin/trak.pl [--debug] [--help] [--formulahelp] [formula1] [formula2]

    # If you like shorter arguments...
    ./bin/trak.pl [-d] [-h] [-f] [formula1] [formula2]

=head1 OPTIONS

=over 4

=item debug

Turn on debugging. This adds a lot of information to the display when the 
forumla parser is running.

=item formulahelp

Get help from the calculator itself. This shows a list of available operators
and functions.

=item help

Show this help information.

=item formula[1, 2, ...]

One or more formulas, wrapped in quotations. One formula per quotation.

=back

=head1 DESCRIPTION

This program tries to parse any formulas passed through the command line 
directly. If no formulas were given, launch an interactive shell that lets
the user enter a formula and execute it immediately.

The calculator is implemented by L<Trak>. See the documentation there
for specifics on how it is implemented.

=head1 USING THE SHELL

When started with no formula arguments, F<trak.pl> starts an interactive 
shell. From this shell, you can enter a single formula from the prompt, and 
the calculator will evaluate it and give you back an answer.

The shell has several additional commands available:

=over 4

=item debug

Toggle debugging mode. When in debugging mode, you will get trace output 
showing how the calculator arrived at a result.

=item exit

Exit the interactive shell.

=item help

Get a list of available operators and functions from the calculator. Equivalent
to the C<--formulahelp> command line argument.

=back

=head1 AUTHOR

Jason A. Crome C< jason@crome-plated.com >

=cut
