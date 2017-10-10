package Test::Mock::File::Constant;

use strict;
use warnings FATAL => 'all';

use Exporter 'import';

# +----------+---------+
# | Position |  Value  |
# +----------+---------+
# |    0     |  Read   |
# +----------+---------+
# |    1     |  Write  |
# +----------+---------+
# |    2     |  Append |
# +----------+---------+
use constant {
    MODE_INPUT        => 4,
    MODE_OUTPUT       => 2,
    MODE_APPEND       => 1,

    MODE_INPUT_TITLE  => 'input',
    MODE_OUTPUT_TITLE => 'output',
    MODE_APPEND_TITLE => 'append',

    READ_METHOD       => 'read',
    READLINE_METHOD   => 'readline',
    SEEK_METHOD       => 'seek',
    PRINT_METHOD      => 'print',
    PRINTF_METHOD     => 'printf',
};

use constant {
    MODE_TITLE_MAP => {
        MODE_INPUT()  => MODE_INPUT_TITLE,
        MODE_OUTPUT() => MODE_OUTPUT_TITLE,
        MODE_APPEND() => MODE_APPEND_TITLE,
    },
};

our @EXPORT = (qw/
        MODE_INPUT
        MODE_OUTPUT
        MODE_APPEND

        MODE_TITLE_MAP

        READ_METHOD
        READLINE_METHOD
        SEEK_METHOD
        PRINT_METHOD
        PRINTF_METHOD
    /);

1;
