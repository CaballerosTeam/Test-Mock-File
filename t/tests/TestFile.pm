package TestFile;

use strict;
use warnings FATAL => 'all';
use parent 'TestCase';

use Test::More;

use Test::Mock::File;
use Test::Mock::File::Constant;


sub setUp: Test(setup) {
    my ($self) = @_;

    $self->{file} = Test::Mock::File->new();
}

sub test_parse_mode__positive: Test(7) {
    my ($self) = @_;

    my $matrix = [
        {
            title    => 'input',
            mode     => '<',
            expected => MODE_INPUT,
        },
        {
            title    => 'output',
            mode     => '>',
            expected => MODE_OUTPUT,
        },
        {
            title    => 'append',
            mode     => '>>',
            expected => MODE_APPEND,
        },
        {
            title    => 'input (read & write)',
            mode     => '+<',
            expected => MODE_INPUT | MODE_OUTPUT,
        },
        {
            title    => 'output (read & write)',
            mode     => '+>',
            expected => MODE_OUTPUT | MODE_INPUT,
        },
        {
            title    => 'append (read & write)',
            mode     => '+>>',
            expected => MODE_APPEND | MODE_INPUT,
        },
        {
            title    => 'append (encoding UTF-8), ',
            mode     => '>>:encoding(utf-8)',
            expected => MODE_APPEND,
        },
    ];

    my $file_obj = $self->file;
    foreach my $hr (@{$matrix}) {
        my $expected = $hr->{expected};
        my $mode = $hr->{mode};
        my $actual = $file_obj->_parse_mode($mode);

        is($actual, $expected, sprintf('MODE for %s matches', $hr->{title}));
    }
}

sub test_parse_mode__negative: Test {
    my ($self) = @_;

    eval {
        $self->file->_parse_mode('r+');
    };

    if ($@) {
        pass('Exception is thrown');
    }
    else {
        fail('Exception is not thrown');
    }
}

sub test_get_mode__3_arguments: Test {
    my ($self) = @_;

    my $fh;
    my $actual = $self->file->_get_mode(\$fh, '>>', '/path/to/some/file');

    is($actual, Test::Mock::File::MODE_APPEND, 'MODE matches');
}

sub test_get_mode__2_arguments: Test {
    my ($self) = @_;

    my $fh;
    my $actual = $self->file->_get_mode(\$fh, '/path/to/another/file');

    is($actual, Test::Mock::File::MODE_INPUT, 'MODE matches');
}

#@property
#@method
#@returns Test::Mock::File
sub file {
    my ($self) = @_;

    return $self->{file};
}

1;
