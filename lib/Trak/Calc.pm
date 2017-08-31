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

# By making this state, it retains its value through multiple calls of calculate().
# Only gets reset by evaluate().
state $iteration = 0;

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

# Calculate is a front-end for evaluate. It throws up a report header, runs the calculation,
# and resets the interation counter when done.
sub calculate ( $self, $formula ) {
    die "No formula provided!\n" unless $formula;

    $self->_log( " #  Token Number Stack          Operator Stack        Action    Remaining" );
    $self->_log( "--- ----- --------------------- --------------------- --------- ---------------" );
    $iteration = 1;
    my $value = $self->_evaluate( $formula );
    $iteration = 0;
    return $value;
}

# Evaluate the function given and return the result.
sub _evaluate ( $self, $formula ) {
    die "No formula provided!\n" unless $formula;
    my( @opstack, @numstack );

    # 
    # Set up reporting.
    #
    # This anonymous subroutine allows us to conveniently, repeatedly call this reporting
    # method, and gives us access to all local vars in calculate(). Cool!
    #
    my $trace = sub ( $action = "", $token = "" ) {
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

    while( length $formula ) {
        my( $token, $type, $arg ) = $self->_pluck_token( \$formula );
        
        # If it's a number, just dump it on the stack and continue.
        if( $type eq "NUM" ) {
            $trace->( "Reduce", $token );
            push @numstack, $token;
        }
        elsif( $type eq "OP" ) {
            # Push the operator on the stack if the stack is empty, or if the precedence is 
            # greater than to the op on top of the stack.
            if( @opstack == 0 or $ops{ $token }{ order } >= $ops{ $opstack[-1] }{ order }) { 
                push @opstack, $token;
                $trace->( "Shift", $token );
            }
            else {
                while( scalar @opstack > 0 and $ops{ $token }{ order } < $ops{ $opstack[-1] }{ order } ) {
                    my $op = pop @opstack;
                    my( $t1, $t2 ) = splice @numstack, -2, 2; # Dumb array hack
                    my $result = $ops{ $op }{ exec }->( $t1, $t2 );
                    push @numstack, $result;
                    $trace->( "Evaluate", $result );
                }
                $trace->( "Reduce", $token );
                push @opstack, $token;
            }
        }
        elsif( $type eq "FUNC" ) {
            my $result = $functions{ $token }{ exec }->( $arg );
            $trace->( "Evaluate", $token );
            push @numstack, $result;
        }
        else {
            die "Unknown token: $token\n";
        }

        ++$iteration;
    }

    # All done. Empty the stacks and evaluate the result.
    my $value = pop @numstack;
    while( @opstack ) {
        my $op = pop @opstack;
        my $t1 = pop @numstack;
        my $result = $ops{ $op }{ exec }->( $t1, $value );
        $trace->( "Calculate", $result );
        ++$iteration; # Calculation takes time too!
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
    if( $$formula =~ /^([-]?\d+\.?\d*?)(.*)$/x ) {
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

        # Get the argument. The second regex *should* have done this, but there
        # is a bug in the Perl regex engine that is causing the second capture to 
        # be extra greedy. I checked this regex against a few different data strings
        # at regex101.com and in Oyster and the regex works as intended... I was able
        # to work around this with a simple search-and-replace, but in doing so, I
        # had to make a little redundant code in the operator and number blocks. :(
        $$formula =~ s/^\s+//;
        $$formula =~ /^([-]?\d+)\s*?\)([^\)]*)$/;
        die "Parse error: ')' expected\n" unless $1;
        $arg = $1;
        $$formula =~ s/$2//g;
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

        # Pass only the parenthetical piece. Make sure we remove it from the original formula.
        my $f2 = $1; $f2 =~ s/^\s+//; $f2 =~ s/\s+$//;
        $token = $self->_evaluate( $f2 );
        $type = "NUM";
        $$formula =~ s/^.*?\)//g;
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

Assumes that function arguments are simple numbers. Could have expanded this
without a lot of additional work. Could have added functions with multiple 
arguments with not a lot of additional work.

Assumed you wanted integers, and that is what the tokenizer checks for.

