package TestCase;

use strict;
use warnings FATAL => 'all';
use parent 'Test::Class';

use Test::Mock::File;

INIT {
    Test::Class->runtests();
}

1;
