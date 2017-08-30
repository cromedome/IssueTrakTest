package Trak::Calc;

# Language features
use v5.24;
use strictures 2;
use Moose;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use namespace::autoclean; # Clean up imported symbols after compilation

# Everything else
use Scalar::Util::Numeric qw( isint );

# Are we debugging? Create get/set methods and let us change this at runtime.
has debug => (
    is  => 'rw',
    isa => 'Bool',
);

#
# Supported operators, their precedence (order), description (help), and 
# implementation.
#
# Operators evaluate left to right usually (think addition and subtraction),
# but in some cases (exponentiation), they implement right to left.
#
my %ops = ( 
    '+'  => { order => 10, exec => sub { $_[0] +  $_[1] }, help => "Addition: +"        },
    '-'  => { order => 10, exec => sub { $_[0] -  $_[1] }, help => "Subtraction: -"     },
    '*'  => { order => 20, exec => sub { $_[0] *  $_[1] }, help => "Multiplication: *"  },
    '/'  => { 
        order => 20, 
        exec  => sub { 
            die "Caclulation error: can't divide by zero!\n" if $_[1] == 0;
            $_[0] /  $_[1];
        }, 
        help  => "Division: /" 
    },
    '%'  => { 
        order => 20, 
        exec  => sub { 
            die "Caclulation error: can't divide by zero!\n" if $_[1] == 0;
            $_[0] %  $_[1];
        }, 
        help  => "Modulus: %" 
    },
    '**' => { order => 30, exec => sub { $_[0] ** $_[1] }, help => "Exponentiation: **" },
);

# TODO: Sin, cos, tan, others?
my %functions = (
    sqrt => { help => "Square Root: sqrt( arg )", exec => sub { return sqrt shift; }},
);

# Evaluate the function given and return the result.
sub calculate ( $self, $formula ) {
    die "No formula provided!\n" unless $formula;

    my $work_formula = $formula;
    my $iteration = 1;
    my @stack;

    while( length $work_formula ) {
        my( $token, $type, $arg ) = $self->_pluck_token( \$work_formula );
        $self->_trace( "Iteration $iteration: Token: $token, Type: $type" );
        $self->_trace( "Iteration $iteration: Remaining formula is '$work_formula'" );

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
            my $result = $functions{ $token }->( $arg );
            $self->_trace( "Iteration $iteration: evaluate $token( $arg ) = $result" );
            push @stack, $result;
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
# There is a bit of redundant code here. This was necessited by a bug I found
# in Perl's regex parser in the formula tokenizer. More below.
#
sub _pluck_token( $self, $formula ) {
    # Ignore whitespace
    $$formula =~ s/^\s+//;

    # Positive or negative number
    my( $token, $type, $arg );
    if( $$formula =~ /^([+-]?\d+\.?\d*?)(.*)$/x ) {
        $token    = $1;
        die "Parse error: $1 isn't an integer!\n" unless isint( $token );
        $type     = "NUM";
        $$formula = $2;
    }
    # Operator
    elsif( $$formula =~ /^(\*\*|[+\-*\/%\\])(.*)$/ ) { 
        $token    = $1;
        $type     = "OP";
        $$formula = $2;
    }
    # Function
    elsif( $$formula =~ /^([a-z]\w+)\s*?\((.*)$/ ) {  
        $token    = $1;
        $type     = "FUNC";
        $$formula = $2;
        $functions{ $token } or die "Undefined function: '$token'\n";
        $self->_trace( "Found function $token" );

        # Get the argument. The second regex *should* have done this, but there
        # is a bug in the Perl regex engine that is causing the second capture to 
        # be extra greedy. I checked this regex against a few different data strings
        # at regex101.com and in Oyster and the regex works as intended... I was able
        # to work around this with a simple search-and-replace, but in doing so, I
        # had to make a little redundant code in the operator and number blocks. :(
        $$formula =~ s/^\s+//;
        $$formula =~ /^([+-]?\d+)\s*?\)([^\)]*)$/;
        die "Parse error: ')' expected\n" unless $1;
        $arg = $1;
        $$formula =~ s/$2//g;
        $self->_trace( "Found argument '$arg'" );
    }
    # TODO: there's a bug here checking for closed parens
    elsif( $$formula =~ /^(\()(.*)$/ ) {
        $$formula = $2;
        $$formula =~ /^(.*?)\)(.*)$/;
        die "Parse error: ')' expected\n" unless $1;

        # Pass only the parenthetical piece. Make sure we remove it from the original
        # formula.
        my $f2 = $1;
        $$formula =~ s/^(.*?)\)//g;
        $self->_trace( "Nested formula is $f2, remaining is $$formula" );
        $token = $self->calculate( $f2 );
        $type = "NUM";
    }
    else {
        $token = $$formula;
        $type  = "UNKNOWN";
    }

    $arg //= ""; # Make sure arg is at least empty string
    return( $token, $type, $arg );
}

# This shows us a log/stack trace of where we are in parsing the formula provided - but
# ONLY if we were invoked with the debugging option!
sub _trace( $self, $message = "") {
    return unless $self->debug;

    my( $package, $file, $line ) = caller;
    say STDERR sprintf "Line %3s: \"%s\"", $line, $message;
}

# Auto-generate some help information in the shell
sub help {
    my $message = "The following operators are available to you in the Trak calculator:\n";
    $message .= $ops{ $_ }{ help } . "\n" foreach keys %ops;
    $message .= "\nThe following functions are also available:\n";
    $message .= $functions{ $_ }{ help } foreach keys %functions;

    return "$message\n";
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

Assumes that function arguments are simple numbers. Could have expanded this
without a lot of additional work. Could have added functions with multiple 
arguments with not a lot of additional work.

Assumed you wanted integers, and that is what the tokenizer checks for.

