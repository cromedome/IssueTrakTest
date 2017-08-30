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
use Math::Trig;

# Are we debugging? Create get/set methods and let us change this at runtime.
has debug => (
    is  => 'rw',
    isa => 'Bool',
);

#
# Supported operators, their precedence (order), association (dir - L is left-to-right,
# R is right-to-left), description (help), and implementation.
#
my %ops = ( 
    '+'  => { order => 10, dir => 'L', exec => sub { $_[0] +  $_[1] }, help => "Addition: +"        },
    '-'  => { order => 10, dir => 'L', exec => sub { $_[0] -  $_[1] }, help => "Subtraction: -"     },
    '*'  => { order => 20, dir => 'L', exec => sub { $_[0] *  $_[1] }, help => "Multiplication: *"  },
    '/'  => { 
        order => 20, 
        dir   => 'L',
        exec  => sub { 
            die "Calculation error: can't divide by zero!\n" if $_[1] == 0;
            $_[0] /  $_[1];
        }, 
        help  => "Division: /" 
    },
    '%'  => { 
        order => 20, 
        dir   => 'L',
        exec  => sub { 
            die "Calculation error: can't mod by zero!\n" if $_[1] == 0;
            $_[0] %  $_[1];
        }, 
        help  => "Modulus: %" 
    },
    '**' => { order => 30, dir => 'R', exec => sub { $_[0] ** $_[1] }, help => "Exponentiation: **" },
);

# List of functions supported
my %functions = (
    sqrt => { help => "Square Root: sqrt( arg )", exec => sub { return sqrt shift; }},
    sin  => { help => "Sine: sin(x)",             exec => sub { return sin shift;  }}, 
    cos  => { help => "Cosine: cos(x)",           exec => sub { return cos shift;  }}, 
    tan  => { help => "Tangent: tan(x)",          exec => sub { return tan shift;  }}, 
);

# Evaluate the function given and return the result.
sub calculate ( $self, $formula ) {
    die "No formula provided!\n" unless $formula;

    my( @opstack, @numstack );
    my $iteration = 1;

    # 
    # Set up reporting.
    #
    # This anonymous subroutine allows us to conveniently, repeatedly call this reporting
    # method, and gives us access to all local vars in calculate(). Cool!
    #
    my $trace = sub ( $action = "", $token = "", $header = 0 ) {
        # Print trace output header
        if( $header ) {
            $self->_log( " #  Token Number Stack          Operator Stack        Action    Remaining" );
            $self->_log( "--- ----- --------------------- --------------------- --------- ---------------" );
            return;
        }

        # Generate a trace message
        $self->_log( sprintf "%-3d %-5s %-21s %-21s %-9s %-15s",
            $iteration,
            $token,
            join( ',', @numstack ),
            join( ',', @opstack ),
            $action,
            $formula,
        );
    };

    $trace->( "", "", 1 ); 
    while( length $formula ) {
        my( $token, $type, $arg ) = $self->_pluck_token( \$formula );

        # If it's a number, just dump it on the stack and continue.
        if( $type eq "NUM" ) {
            push @numstack, $token;
            $trace->( "Reduce", $token );
        }
        elsif( $type eq "OP" ) {
            # See if this operator has a higher precedence than the one at the top of the
            # stack. If not, pop the one off the top of the stack, pop two numbers off the 
            # number stack, evaluate the result, and push the result back on the number stack.
            if( @opstack == 0 or $ops{ $token }{ order } >= $ops{ $opstack[-1] }{ order }) { 
                push @opstack, $token;
                $trace->( "Shift", $token );
            }
            else {
                my $t2 = pop @numstack;
                my $op = pop @opstack;
                my $t1 = pop @numstack;
                my $result = $ops{ $op }{ exec }->( $t1, $t2 );
                push @numstack, $result;
                push @opstack, $token;
                $trace->( "Evaluate", $result );
            }
        }
        elsif( $type eq "FUNC" ) {
            my $result = $functions{ $token }{ exec }->( $arg );
            push @numstack, $result;
            $trace->( "Evaluate", $token );
        }
        else {
            die "Unknown token: $token\n";
        }

        ++$iteration;
    }

    my $value = $self->_evaluate;
    return $value;
}

# TODO: this
sub _evaluate( $self ) {
    # All done! Traverse the stacks from the bottom up and calculate the result
    # TODO: precedence bug when high-precedence operator is at end of formula
    #my $value = pop @{ $self->_numstack };;
    #while( @tokens ) {
        #my $op = shift @tokens;
        #my $t1 = shift @tokens;
        #my $result = $ops{ $op }{ exec }->( $value, $t1 );
        #$self->_trace( "$value $op $t1 = $result" );
        #$value = $result;
    #}

    #return $value;
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
# TODO: whitepsace handling bug
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
        $functions{ $token } or die "Unknown function: '$token'\n";
        #$self->_trace( "Found function $token" );

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
        #$self->_trace( "Found argument '$arg'" );
    }
    elsif( $$formula =~ /^(\()(.*)$/ ) {
        # Handle parenthetical expressions.
        # These aren't tokens per se, but they are something that get picked up during
        # formula parsing. When we find one, run it back through calculate() to solve
        # it, then put the result on the stack in place of the expression.
        die "Parse error: expected ')'\n" unless $2;
        $$formula = $2;
        $$formula =~ /^(.*?)\)(.*)$/;
        die "Parse error: ')' expected\n" unless $1;

        # Pass only the parenthetical piece. Make sure we remove it from the original
        # formula.
        my $f2 = $1;
        $$formula =~ s/^(.*?)\)//g;
        #$self->_trace( "Nested formula is $f2, remaining is $$formula" );
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

sub _log( $self, $message ) {
    return unless $self->debug;
    say STDERR $message;
}

# Auto-generate some help information in the shell
sub help {
    my $message = "The following operators are available to you in the Trak calculator:\n";
    $message .= '- ' . $ops{ $_ }{ help } . "\n" foreach keys %ops;
    $message .= "\nThe following functions are also available:\n";
    $message .= '- ' . $functions{ $_ }{ help } . "\n" foreach keys %functions;

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

