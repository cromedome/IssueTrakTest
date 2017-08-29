package Trak::Calc;

# Language features
use v5.24;
use strictures 2;
use Moose;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use namespace::autoclean; # Clean up imported symbols after compilation

# Are we debugging? Create get/set methods and let us change this at runtime.
has debug => (
    is  => 'rw',
    isa => 'Bool',
);

#
# Supported operators, their precedence (order), direction (L or R), and 
# implementation.
#
# Operators evaluate left to right usually (think addition and subtraction),
# but in some cases (exponentiation), they implement right to left.
#
# TODO: add desc for help
my %ops = ( 
    '+'  => { order => 10, dir => 'L', exec => sub { $_[0] +  $_[1] }},
    '-'  => { order => 10, dir => 'L', exec => sub { $_[0] -  $_[1] }},
    '*'  => { order => 20, dir => 'L', exec => sub { $_[0] *  $_[1] }},
    '/'  => { order => 20, dir => 'L', exec => sub { $_[0] /  $_[1] }},
    '%'  => { order => 20, dir => 'L', exec => sub { $_[0] %  $_[1] }},
    '**' => { order => 30, dir => 'R', exec => sub { $_[0] ** $_[1] }},
);

# TODO: Sin, cos, tan, max, min, others?
# TODO: add desc for help
my %functions = (
    sqrt => sub { return sqrt shift; },
);

# Evaluate the function given and return the result.
sub calculate ( $self, $formula ) {
    die "No formula provided!\n" unless $formula;

    my $work_formula = $formula;
    my $iteration = 1;
    my( @opstack, @numstack );
    my @stack;

    while( length $work_formula ) {
        my( $token, $type ) = $self->_pluck_token( \$work_formula );
        $self->_trace( "Iteration $iteration: Token: $token, Type: $type" );
        $self->_trace( "Iteration $iteration: Remaining formula is '$work_formula'" );

        # Find position of token (where will need this)

        # If it's a number, just dump it on the stack and continue.
        if( $type eq "NUM" ) {
            push @stack, $token;
        }
        elsif( $type eq "OP" ) {
            # See if this operator has a higher precedence than the one at the top of the
            # stack. If not, pop the one off the top of the stack, pop two numbers off the 
            # number stack, evaluate the result, and push the result back on the number stack.
            if( scalar @stack < 2 or $ops{ $token }{ order } >= $ops{ $stack[$#stack - 1] }{ order }) { 
                push @stack, $token;
            }
            else {
                my $t2 = pop @stack;
                my $op = pop @stack;
                my $t1 = pop @stack;
                my $result = $ops{ $op }{ exec }->( $t1, $t2 );
                $self->_trace( "Iteration $iteration: calculate $t1 $op $t2 = $result" );
                push @stack, $result;
                push @stack, $token;
            }
        }
        elsif( $type eq "FUNC" ) {
        }
        else {
            die "Unknown token: $token\n";
        }
        $self->_trace( "Iteration $iteration: Current stack: " . join( ',', @stack ));

        ++$iteration;
    }

    # All done! Traverse the stacks from the bottom up and calculate the result
    my $value = shift @stack;
    while( @stack ) {
        my $op = shift @stack;
        my $t1 = shift @stack;
        my $result = $ops{ $op }{ exec }->( $value, $t1 );
        $self->_trace( "Calculating $value $op $t1 = $result" );
        $value = $result;
    }

    return $value;
}

#
# Determine what a token is. Currently can be one of the following:
# - Positive or negative number
# - Operator (from the approved list)
# - Function (from the approved list)
# - Another expression (in parenthesis)
# 
# $formula is passed by reference, so as we pluck tokens, the formula
# gets smaller. When we reach the end of the formula, we know it's time
# to calculate.
#
sub _pluck_token( $self, $formula ) {
    # Ignore whitespace
    $$formula =~ s/^\s+//;

    # Positive or negative number
    my $type;
    if( $$formula =~ /^([+-]?\d+)(.*)$/x ) {
        $type = "NUM";
    }
    # Operator
    elsif( $$formula =~ /^(\*\*|[+\-*\/%\\])(.*)$/ ) { 
        $type = "OP";
    }
    
    $$formula = $2;
    return( $1, $type );
}

# This shows us where we are in parsing the formula by superimposing an inverted
# ? character on top of our position in the formula.
sub _where { 
    # pass original formula, token, find location, return modified formula
    #my $s = $_;
    #substr($s, pos || 0, 0) = "\267";
    #return $s;
}

# This shows us a log/stack trace of where we are in parsing the formula provided - but
# ONLY if we were invoked with the debugging option!
sub _trace( $self, $message = "") {
    #return unless $self->debug;

    my( $package, $file, $line ) = caller;
    say STDERR sprintf "Line %d: \"%s\"", $line, $message;
}

# Speed up object construction, but make classes immutable
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Trak::Calc

=head1 DESCRIPTION

This implements a modified Shunting Yard Algorithm 
(L<https://en.wikipedia.org/wiki/Shunting-yard_algorithm>). Being a dynamic
language, Perl makes some things a bit easier than the way Wikipedia 
outlines the algorithm.

Since Perl allows me to look back on the stack, I can implement this with a 
single stack rather than multiple stacks.

