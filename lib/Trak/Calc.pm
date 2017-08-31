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
# Supported operators, their precedence (order), association (dir) - L is left-to-right, R is right
# to left, description (help), and implementation.
#
my %ops = ( 
    '+' => { order => 10, dir => "L", exec => sub { $_[0] +  $_[1] }, help => "Addition: +"        },
    '-' => { order => 10, dir => "L", exec => sub { $_[0] -  $_[1] }, help => "Subtraction: -"     },
    '*' => { order => 20, dir => "L", exec => sub { $_[0] *  $_[1] }, help => "Multiplication: *"  },
    '/' => { 
        order => 20, 
        dir   => 'L',
        exec  => sub { 
            die "Calculation error: can't divide by zero!\n" if $_[1] == 0;
            $_[0] /  $_[1];
        }, 
        help  => "Division: /" 
    },
    '%' => { 
        order => 20, 
        dir   => 'L',
        exec  => sub { 
            die "Calculation error: can't mod by zero!\n" if $_[1] == 0;
            $_[0] %  $_[1];
        }, 
        help  => "Modulus: %" 
    },
    '^' => { order => 30, dir => 'R', exec => sub { $_[0] ** $_[1] }, help => "Exponentiation: ^" },
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
sub calculate ( $ self, $formula ) {
    die "No formula provided!\n" unless $formula;

    $self->_log( " #  Token Number Stack          Operator Stack        Action    Remaining" );
    $self->_log( "--- ----- --------------------- --------------------- --------- ---------------" );
    $iteration = 1;
    my $value = $self->_evaluate( $formula );
    $iteration = 0;
    return $value;
}

# Evaluate the function given and return the result.
sub _evaluate ( $self,  $formula ) {
    die "No formula provided!\n" unless $formula;
    $formula =~ s/^\s+//; # Remove leading whitespace

    my( @opstack, @numstack );

    # This anonymous subroutine allows us to conveniently, repeatedly call this reporting
    # method, and gives us access to all local vars in calculate(). Cool!
    my $trace = sub ( $action = "", $token = "" ) {
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
        #$formula =~ s/([\d\)])\(/$1*(/; # Treat any operand next to a paren as multiplication
        my( $token, $type, $arg ) = $self->_pluck_token( \$formula );
        
        # If it's a number, just dump it on the stack and continue.
        if( $type eq "NUM" ) {
            $trace->( "Reduce", $token );
            push @numstack, $token;
            $formula = "*${formula}" if $formula =~ /^\(/; # Treat any operand next to a paren as multiplication
        }
        elsif( $type eq "OP" ) {
            # Push the operator on the stack if the stack is empty, or if the precedence is 
            # greater than to the op on top of the stack, or if the operator is right associative
            # and the precedence is the same.
            if( @opstack == 0 
                or ($ops{ $token }{ order } >= $ops{ $opstack[-1] }{ order } and $ops{ $token }{ order } eq 'L' ) 
                or ($ops{ $token }{ order } == $ops{ $opstack[-1] }{ order } and $ops{ $token }{ order } eq 'R' ) 
            ) { 
                push @opstack, $token;
                $trace->( "Shift", $token );
            }
            else {
                while( scalar @opstack > 0 and $ops{ $token }{ order } < $ops{ $opstack[-1] }{ order } ) {
                    my $op = pop @opstack;
                    if( scalar @numstack >= 2 ) {
                        my( $t1, $t2 ) = splice @numstack, -2, 2; # Dumb array hack
                        my $result = $ops{ $op }{ exec }->( $t1, $t2 );
                        push @numstack, $result;
                        $trace->( "Evaluate", $token );
                        ++$iteration; # This bumps the counter too...
                    }
                    else {
                        die "Parse error: too many operators, not enough operands!\n";
                    }
                }
                $trace->( "Shift", $token );
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
        my $t1 = pop @numstack or die "Parse error: too many operators, not enough operands!\n";
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
# There is a bit of redundant code here. This was necessitated by a bug I found
# in Perl's regex parser in the formula tokenizer. More below.
#
sub _pluck_token( $self, $formula ) {
    # Positive or negative number
    my( $token, $type, $arg );
    if( $$formula =~ /^([-]?\d+\.?\d*?)(.*)$/x ) {
        $token    = $1;
        die "Parse error: $1 isn't an integer!\n" unless isint( $token );
        $type     = "NUM";
        $$formula = $2;
    }
    # Operator
    elsif( $$formula =~ /^(\^|[+\-*\/%\\])(.*)$/ ) { 
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
        # formula parsing. When we find one, run it back through _evaluate() to solve
        # it, then put the result on the stack in place of the expression.
        die "Parse error: ')' expected\n" unless $2;
        $$formula = $2;
        $$formula =~ /^(.*?)\)(.*)$/;
        die "Parse error: ')' expected\n" unless $1;

        # Pass only the parenthetical piece. Make sure we remove it from the original formula.
        my $f2 = $1; $f2 =~ s/^\s+//; $f2 =~ s/\s+$//;
        $token = $self->_evaluate( $f2 );
        $type = "NUM";
        $$formula =~ s/^.*?\)\s*//g;
        $$formula = "*$${formula}" if $$formula =~ /^\(/; # Treat any operand next to a paren as multiplication
    }
    else {
        $token = $$formula;
        $type  = "UNKNOWN";
    }

    $$formula =~ s/^\s+//; # Remove whitespace
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
    $message .="\nImplicit multiplication (i.e. \"5(4+1)\") is also supported.";

    return "$message\n";
}

# Speed up object construction, but make classes immutable
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Trak::Calc - implement a calculator/forumla parser and evaluator in Perl.

=head1 DESCRIPTION

This implements a modified Shunting Yard Algorithm 
(L<https://en.wikipedia.org/wiki/Shunting-yard_algorithm>). For the most part,
we adhere to the process described, but Perl being a dynamic makes some 
implementation details a bit easier. 

=head2 ASSUMPTIONS/REQUIREMENTS

From the email explaining the test requirements, the calculator was designed
to meet the following requirements:

=over 4

=item *

Operands B<must> be integers.

=item *

Don't assume that operands, operators, and functions will be regularly spaced
apart (this made parsing interesting!).

=back

=head1 HOW IT WORKS

C<_evaluate()> is invoked with a single formula. The method iterates over that
formula, calling C<_pluck_token()> to pull the next token from the left side
of the formula. The token is returned, and is either pushed on the number 
stack, the operator stack, or is evaluated as a function. When it runs out
of tokens, C<_evaluate()> starts popping operators and operands off their
respective stacks and works its way to an eventual result.

C<_pluck_token()> actually does a fair amount of heavy lifting. Since there 
is no guarantee that tokens are evenly spaced (or spaced at all), some 
rather complicated regular expressions were needed to extract each type of
token from the formula (rather than simply splitting the formula on any 
whitespace). When it identifies a token, it returns the token and its type
(number, operator, or function) back to C<_evaluate()>. If it finds a 
parenthetical expression, it calls C<_evaluate()> with the contents of that
expression.

=head2 SUPPORTED OPERATORS

The following operators are supported:

=over 4

=item Addition (+)

=item Subtraction (-)

=item Multiplication (*)

Multiplication also works implicitly: i.e., "5(4+1)" is evaluated to be 25,
as is "(3+2)(4+1)".

=item Division (/)

=item Modulus (%)

=item Exponentiation (^)

=item Parenthesis ()

=back

=head2 SUPPORTED FUNCTIONS

The following functions are also supported:

=over 4

=item Square Root - sqrt(x)

=item Sine - sin(x)

=item Cosine - cos(x)

=item Tangent - tan(x)

=back

=head2 WRITING YOU OWN OPERATORS AND FUNCTIONS

It's pretty easy to add your own operators. In the C<%ops> hash, the character
representing the operator must be provided, its order of precedence (higher
values are evaluated first), a help description (which is shown by the C<help()>
method) and finally, an anonymous subroutine that takes two arguments and 
implements said operator.

Functions work rather similarly. In the C<%functions> hash, a function name 
must be provided, along with a help description, and finally, a single-argument
anonymous function that implements that function. Currently, functions may only
take a single argument, and contents in the argument are not evaluated as a 
mathematical expression.

=head1 PUBLIC METHODS

=head2 calculate()

This is the public interface to the calculator. When it is called, it sets up
the trace report, and invokes C<_evaluate()> for the function provided. It
takes a single argument: the function to be evaluated.

=head2 debug()

When called with no arguments, returns a boolean that indicates whether or not
debugging is enabled. When passed a boolean argument, enables or disables 
debugging.

=head2 help()

Returns an auto-generated help page showing the supported list of operators 
and functions. Takes no arguments.

=head1 PRIVATE METHODS

=head2 _evaluate()

This is the brain of the calculator, and does the actual work of calculation.
Takes a single argument: the function to be evaluated. Returns the result of
the evaluation.

=head2 _log()

A convenience method to send a message to C<STDERR>. Takes a single argument:
the message to be logged. If we are not in debugging mode, this method does
nothing. 

=head2 _pluck_token()

When given a formula, plucks the next token off the left side of it. Plucking
is a destructive operation, and as such, the formula must be passed by 
reference. Returns a list that contains the token, the type of the token (NUM,
OP, or FUNC), and in the case of a function, an optional argument item.

=head1 AUTHOR

Jason A. Crome C< jason@crome-plated.com >

=cut
