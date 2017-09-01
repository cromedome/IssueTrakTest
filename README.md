# Trak::Calc - A calculator/formula parser, built in Perl

This README provides instructions for installing and using the calculator
program developed for the programming test.

Even though this calculator was developed on MacOS and Linux, it runs fine
on Windows. These installation instructions are Windows-centric. If help is
needed to install and run this on a Mac or Linux machine, please contact me.

## Prerequisites

- Perl 5.24.x

Most Linux distros and Macs do not ship with a modern enough Perl distribution
to run this calculator.

## Installation

Download and install Perl from [ActiveState](https://www.activestate.com/activeperl/downloads)

Next, you must clone this Git repo to your machine.

Once installed, you can download a prepackaged Zip archive containing all
the modules for ActivePerl from [me](https://crome-plated.com/issuetrak/perl.zip).
This zip can be extracted over your ActiveState Perl install.

If you'd rather skip the downloading of the zip and install the modules I use
for yourself:

```
c:\projectdir> modules.bat
```

If you are on Linux or MacOS, run this instead:
```
~/projectdir> sudo cpan install App::cpanminus
~/projectdir> sudo cpanm --installdeps . --with-develop --with-all-features
```

## Running the Application

There are a few different ways to invoke the application:

```
# Run in interactive mode, no debugging:
c:\projectdir> perl trak.pl

# Run in interactive mode with debugging:
c:\projectdir> perl trak.pl -d

# Evaluate a specific formula with debugging:
c:\projectdir> perl trak.pl -d "1 + 2 * 3 + 4"

```

Other command line arguments are explained in the documentation.

## Running the Tests

Running tests is easy!

```
# This runs tests with summary output
c:\projectdir> prove -l 

# This runs tests with detail output
c:\projectdir> prove -lv
```

If you'd rather just look at test output without running the tests, the `docs/` 
subfolder contains summary and verbose test output in the `docs/TestDetail.txt` 
and `docs/TestSummary.txt` files.

## Documentation

Pregenerated documentation files are in the `docs/` subdirectory within the
project directory. To view documentation straight from the application itself,
use `perldoc`:

```
c:\projectdir> perldoc trak.pl
c:\projectdir> perldoc lib/Trak.pm

```

