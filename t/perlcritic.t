#!/usr/bin/env perl

use Test::Most;
use Test::Perl::Critic;
all_critic_ok( 'bin', 'lib', 't' );

