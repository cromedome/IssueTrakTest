#!/usr/bin/env perl

use lib './lib';
use strictures 2;
use Test::More tests => 3;

use_ok 'Trak';
use_ok 'Trak::Calc';
use_ok 'Trak::CLI';
