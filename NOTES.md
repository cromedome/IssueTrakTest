# Overview

Here are a few extra thoughts regarding the development of this code.

I wanted to deliver something that looked nice, worked flawlessly, met all
of the guidelines you specified, and demonstrated a wide range of abilities.
I think this comes pretty close to meeting all that.

Specific skills I think have been showcased to greater or lesser extent:

- Knowledge of Perl 
- Testing
- Documentation
- Shell scripting
- Ability to follow directions and pay attention to detail

# Requirements

I would have been remiss, I think, assuming that you wouldn't put examples
in this calculator that were exactly what you laid out in your email. 
Implementing it differently would have been much easier, but that's not
how I roll!

I opted for the Shunting Yard algorithm because it's reasonably well known,
easy to follow, and very effective at parsing complex equations. I believe
that I made the calculator fairly easy to extend, too.

# Installation

I know you are not Perl people, so I tried to make this as painless as
possible.

# Testing

I included a basic test suite that makes sure all code compiles cleanly
(`t/001sanity.t`), adheres to modern Perl programming practices 
(`t/perlcritic.t`), and does a thorough testing of calculator functions
(`t/calc.t`).

# Tools Used

This was lovingly crafted with Perl. More specifically, all of the following 
were used throughout the development of this:

- Perl 5.24.2
- Vim
- Git
- MacOS Sierra
- Ubuntu Linux 16.04
- Windows 10 (for testing and packaging)

