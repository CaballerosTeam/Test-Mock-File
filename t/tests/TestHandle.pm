package TestHandle;

use strict;
use warnings FATAL => 'all';
use parent 'TestCase';

use Fcntl;

use Test::More;
use Sub::Override;

use Test::Mock::File;
use Test::Mock::File::Constant;
use Test::Mock::File::Handle;

use constant {
    FIRST_WORD  => 'first',
    SECOND_WORD => 'line',
};

use constant {
    LINES => [FIRST_WORD().' '.SECOND_WORD, '    Second Line', '        THIRD line'],
    LINE_SEPARATOR => "%%\n",
};


sub setUp: Test(setup) {
    my ($self) = @_;

    $self->{old_line_separator} = $/;
    $/ = LINE_SEPARATOR;

    my $content = join($/, @{LINES()});

    $self->{handle} = Test::Mock::File::Handle->TIEHANDLE(content => \$content, mode => MODE_INPUT);
    $self->{content} = $content;
}

sub tearDown: Test(teardown) {
    my ($self) = @_;

    $/ = $self->{old_line_separator};
}

sub test_prerequisites: Test(2) {
    my ($self) = @_;

    isa_ok($self->handle, 'Test::Mock::File::Handle');
    ok($self->handle->is_opened, 'New handle is opened');
}

sub test_TIEHANDLE__exception: Test {
    eval {
        Test::Mock::File::Handle->TIEHANDLE(content => 'bla');
    };

    if ($@) {
        pass('Exception is thrown');
    }
    else {
        fail('Exception is not thrown');
    }
}

sub test_TIEHANDLE__ok: Test(3) {
    my $content = 'Darth Vader';

    my $matrix = [
        {
            title  => 'input',
            mode   => MODE_INPUT,
            cursor => 0,
        },
        {
            title  => 'output',
            mode   => MODE_OUTPUT,
            cursor => 0,
        },
        {
            title  => 'append',
            mode   => MODE_APPEND,
            cursor => length($content),
        },
    ];

    foreach my $hr (@{$matrix}) {
        my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(
            content => \$content,
            mode    => $hr->{mode}
        );

        my $actual = $handle->cursor;
        my $expected = $hr->{cursor};

        is($actual, $expected, sprintf("Cursor position matches if MODE is '%s'", $hr->{title}));
    }
}

sub test_lines: Test(5) {
    my ($self) = @_;

    my $lines_count = scalar(@{LINES()});
    my $overhead = 2;
    my $iterations_count = $lines_count + $overhead;

    foreach my $offset (0..$iterations_count-1) {
        my $expected_line_number = $lines_count - $offset < 0 ? 0 : $lines_count - $offset;
        my $actual_line_number = scalar(@{$self->handle->lines});

        is($actual_line_number, $expected_line_number, sprintf('Lines count is %s', $actual_line_number));

        shift(@{$self->handle->lines});
    }
}

sub test_READLINE__handle_is_closed: Test {
    my ($self) = @_;

    my $handle = $self->handle;
    $handle->set_is_opened(0);

    eval {
        $self->handle->READLINE();
    };

    if (my $err = $@) {
        like($err, qr/readline\(\) on closed filehandle/, 'Exception is thrown');
    }
    else {
        fail('Exception is not thrown');
    }
}

sub test_READLINE_multi_line_content: Test(3) {
    my ($self) = @_;

    foreach my $idx (0..$#{LINES()}) {
        my $line = LINES->[$idx];
        my $expected_line = $idx == $#{LINES()} ? $line : $line.LINE_SEPARATOR;
        my $actual_line = $self->handle->READLINE();
        is($actual_line, $expected_line, 'Text line match');
    }
}

sub test_READLINE_single_line_content: Test(3) {
    my $expected_line = 'Foo Egg';
    my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(content => \$expected_line);

    foreach my $idx (0..2) {
        my $actual_line = $handle->READLINE();
        if ($idx == 0) {
            is($actual_line, $expected_line, 'Text line match');
        }
        else {
            ok(!$actual_line, 'READLINE return False');
        }
    }
}

sub test_READ__handle_is_closed: Test {
    my ($self) = @_;

    my $handle = $self->handle;
    $handle->set_is_opened(0);

    my $buffer;
    eval {
        $self->handle->READ($buffer, 8);
    };

    if (my $err = $@) {
        like($err, qr/read\(\) on closed filehandle/, 'Exception is thrown');
    }
    else {
        fail('Exception is not thrown');
    }
}

sub test_READ_from_beginning: Test(2) {
    my ($self) = @_;

    my $expected_length = length(FIRST_WORD);
    my $buffer;
    my $actual_length = $self->handle->READ($buffer, $expected_length);

    is($buffer, FIRST_WORD, 'Content in buffer match while read from beginning');
    is($actual_length, $expected_length, 'Return number of bytes actually read from beginning');
}

sub test_READ_not_from_beginning: Test(2) {
    my ($self) = @_;

    my $offset = length(FIRST_WORD) + 1;
    my $expected_length = length(SECOND_WORD);
    my $buffer;
    my $actual_length = $self->handle->READ($buffer, $expected_length, $offset);

    is($buffer, SECOND_WORD, 'Content in buffer match while read not from beginning');
    is($actual_length, $expected_length, 'Return number of bytes actually read not from beginning');
}

sub test_READ_empty_content: Test(2) {
    my $content = '';
    my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(content => \$content);
    my $buffer;
    my $actual_length = $handle->READ($buffer, 16);

    is($buffer, undef, 'Content in buffer is undef if content is empty string');
    is($actual_length, 0, 'Return number of bytes is 0 if content is empty string');
}

sub test_READ__wrong_mode: Test(2) {
    my $buffer;
    foreach my $mode (MODE_OUTPUT, MODE_APPEND) {
        my $content = '';
        my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(content => \$content, mode => $mode);
        my $mode_title = MODE_TITLE_MAP->{$mode};

        eval {
            $handle->READ($buffer, 16);
        };

        if (my $err = $@) {
            like($err, qr/opened only for output/, sprintf('MODE %s, exception is thrown', $mode_title));
        }
        else {
            fail(sprintf('MODE %s, exception is not thrown', $mode_title));
        }
    }
}

sub test_set_cursor: Test(3) {
    my ($self) = @_;

    eval {
        $self->handle->set_cursor();
    };

    if ($@) {
        ok(1, 'Exception if set undef to cursor');
    }
    else {
        fail('No exception if set undef to cursor');
    }

    my $expected_offset = 10;
    ok($self->handle->set_cursor($expected_offset), 'Setter returned True');
    is($self->handle->cursor, $expected_offset, 'Property returned an offset');
}

sub test_SEEK__handle_is_closed: Test {
    my ($self) = @_;

    my $handle = $self->handle;
    $handle->set_is_opened(0);

    eval {
        $self->handle->SEEK(0, 1);
    };

    if (my $err = $@) {
        like($err, qr/seek\(\) on closed filehandle/, 'Exception is thrown');
    }
    else {
        fail('Exception is not thrown');
    }
}

sub test_SEEK_default: Test(2) {
    my ($self) = @_;

    my $expected_offset = 10;
    ok($self->handle->SEEK($expected_offset), 'SEEK returned True');
    is($self->handle->cursor, $expected_offset, 'Offset match');
}

sub test_SEEK_from_beginnig: Test(2) {
    my ($self) = @_;

    my $expected_offset = $self->handle->content_length + 11;
    ok($self->handle->SEEK($expected_offset, Fcntl::SEEK_SET), 'SEEK returned True');
    is($self->handle->cursor, $self->handle->content_length, 'Offset match');
}

sub test_SEEK_from_cursor: Test(2) {
    my ($self) = @_;

    my $offset = 4;
    my $cursor = 12;
    my $expected_offset = $cursor + $offset;

    $self->handle->set_cursor($cursor);

    ok($self->handle->SEEK($offset, Fcntl::SEEK_CUR), 'SEEK returned True');
    is($self->handle->cursor, $expected_offset, 'Offset match');
}

sub test_SEEK_from_end: Test(3) {
    my ($self) = @_;

    my $offset = -1 * ($self->handle->content_length+6);

    ok($self->handle->SEEK($offset, Fcntl::SEEK_END), 'SEEK returned True');
    is($self->handle->cursor, 0, 'Offset match');

    eval {
        $self->handle->SEEK(10, Fcntl::SEEK_END);
    };

    if ($@) {
        ok(1, 'Exception if SEEK from end with positive offset');
    }
    else {
        fail('No exception if SEEK from end with positive offset');
    }
}

sub test_SEEK_wrong_whence: Test {
    my ($self) = @_;

    eval {
        $self->handle->SEEK(10, 5);
    };

    if ($@) {
        ok(1, 'Exception if call SEEK with wrong WHENCE');
    }
    else {
        fail('No exception if call SEEK with wrong WHENCE');
    }
}

sub test_SEEK_undef_offset: Test {
    my ($self) = @_;

    eval {
        $self->handle->SEEK(undef, Fcntl::SEEK_SET);
    };

    if ($@) {
        ok(1, 'Exception if call SEEK with undef OFFSET');
    }
    else {
        fail('No exception if call SEEK with undef OFFSET');
    }
}

sub test_content_length: Test(7) {
    my $data = ['', 'a', chr(hex('0xFB')), 'жзл', 'abcd',
        'The quick brown fox jumps over the lazy dog',
        'Съешь ещё этих мягких французских булок, да выпей же чаю',
    ];

    foreach my $content (@{$data}) {
        use bytes;

        my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(content => \$content);
        my $expected_length = length($content);

        is($handle->content_length, $expected_length, sprintf("Content length match for '%s'", $content));

        no bytes;
    }
}

sub test_set_is_opened: Test(3) {
    my ($self) = @_;


    eval {
        $self->handle->set_is_opened();
    };

    if ($@) {
        ok(1, 'Exception if set undef as an open flag');
    }
    else {
        fail('No exception if set undef as an open flag');
    }

    my $expected_is_opened = 0;
    ok($self->handle->set_is_opened($expected_is_opened), 'Setter returned True');
    is($self->handle->is_opened, $expected_is_opened, 'Property returned an open flag');
}

sub test_CLOSE: Test(3) {
    my ($self) = @_;

    ok($self->handle->is_opened, 'Handle is opened before the CLOSE method call');
    ok($self->handle->CLOSE(), 'CLOSE method returned True');
    ok(!$self->handle->is_opened, 'Handle is closed after the CLOSE method call');
}

sub test_check_handle__handle_ok: Test {
    my ($self) = @_;

    ok($self->handle->check_handle(READLINE_METHOD), 'Check method returned True');
}

sub test_check_handle__handle_is_closed: Test {
    my ($self) = @_;

    my $handle = $self->handle;
    $handle->set_is_opened(0);

    my $method_name = READLINE_METHOD;
    eval {
        $handle->check_handle($method_name);
    };

    if (my $err = $@) {
        like($err, qr/$method_name\(\) on closed filehandle/, 'Exception is thrown');
    }
    else {
        fail('Exception is not thrown');
    }
}

sub test_check_handle__handle_has_wrong_mode: Test(4) {
    my $matrix = [
        {
            method    => READ_METHOD,
            mode      => MODE_OUTPUT,
            direction => MODE_TITLE_MAP->{MODE_OUTPUT()},
        },
        {
            method    => READLINE_METHOD,
            mode      => MODE_APPEND,
            direction => MODE_TITLE_MAP->{MODE_OUTPUT()},
        },
        {
            method    => PRINT_METHOD,
            mode      => MODE_INPUT,
            direction => MODE_TITLE_MAP->{MODE_INPUT()},
        },
        {
            method    => PRINTF_METHOD,
            mode      => MODE_INPUT,
            direction => MODE_TITLE_MAP->{MODE_INPUT()},
        },
    ];

    foreach my $hr (@{$matrix}) {
        my $mode = $hr->{mode};
        my $method = $hr->{method};

        my $content = '';
        my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(content => \$content, mode => $mode);

        eval {
            $handle->check_handle($method);
        };

        my $mode_title = MODE_TITLE_MAP->{$mode};
        if (my $err = $@) {
            my $direction = $hr->{direction};
            like($err, qr/opened only for $direction/,
                sprintf('MODE %s, method %s, exception is thrown', $mode_title, $method));
        }
        else {
            fail(sprintf('MODE %s, method %s, exception is not thrown', $mode_title, $method));
        }
    }
}

sub test_uid: Test(2) {
    my ($self) = @_;

    my $expected_file_descriptor = 10;
    my $override = Sub::Override->new();
    $override->replace('Scalar::Util::refaddr', sub ($) { return $expected_file_descriptor });

    my $actual_file_descriptor = $self->handle->uid();
    is($actual_file_descriptor, $expected_file_descriptor, 'File desctiptor matches');

    $override->replace('Scalar::Util::refaddr', sub ($) { return 99 });

    $actual_file_descriptor = $self->handle->uid();
    is($actual_file_descriptor, $expected_file_descriptor, "'uid' method is lazy");
}

sub test_FILENO: Test(2) {
    my ($self) = @_;

    my $handle = $self->handle;

    my $file_descriptor = $handle->FILENO();
    ok(Scalar::Util::looks_like_number($file_descriptor), 'File descriptor is returned');

    $handle->set_is_opened(0);
    $file_descriptor = $handle->FILENO();
    is($file_descriptor, undef, 'File desctiptor undefined');
}

sub test_PRINT__set_cursor: Test(2) {
    my ($first_name, $middle_name, $last_name, $wrong_name) = (qw/Homer Jay Simpson John/);

    my $original_content = join(' ', $first_name, $wrong_name).$last_name;
    my $expected_content = join(' ', $first_name, $middle_name, $last_name);

    my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(
        content => \$original_content,
        mode    => MODE_OUTPUT,
    );

    my $offset = length($first_name) + 1;
    $handle->SEEK($offset, Fcntl::SEEK_SET);

    my $out = $handle->PRINT(split(//, $middle_name), ' ');

    is($handle->content, $expected_content, 'Changed content matches');
    ok($out, 'PRINT method returned True');
}

sub test_PRINT__append_once: Test(3) {
    my $content = <<TEXT;
First
Second
Third
TEXT

    my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(
        mode => MODE_APPEND,
        content => \$content,
    );

    my $old_content = $handle->content;
    my $old_content_length = $handle->content_length;

    my $new_line = <<TEXT;
This is new line!
TEXT

    my $out = $handle->PRINT($new_line);

    my $expected_content = $old_content.$new_line;
    my $new_content_length = $handle->content_length;

    is($handle->content, $expected_content, 'Content matches');
    isnt($old_content_length, $new_content_length, 'Content length is reseted');
    ok($out, 'PRINT method returned True');
}

sub test_PRINT__wrong_mode: Test {
    my ($self) = @_;

    my $handle = $self->handle;

    eval {
        $handle->PRINT('bla');
    };

    if (my $err = $@) {
        like($err, qr/opened only for input/, 'Exception is thrown');
    }
    else {
        fail('Exception is not thrown');
    }
}

sub test_PRINTF__set_cursor: Test(2) {
    my ($first_name, $middle_name, $last_name, $wrong_name) = (qw/Homer Jay Simpson John/);

    my $original_content = join(' ', $first_name, $wrong_name).$last_name;
    my $expected_content = join(' ', $first_name, $middle_name, $last_name);

    my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(
        content => \$original_content,
        mode    => MODE_OUTPUT,
    );

    my $offset = length($first_name) + 1;
    $handle->SEEK($offset, Fcntl::SEEK_SET);

    my $out = $handle->PRINTF('%s ', $middle_name);

    is($handle->content, $expected_content, 'Changed content matches');
    ok($out, 'PRINT method returned True');
}

sub test_PRINTF__append_once: Test(3) {
    my $content = <<TEXT;
First
Second
Third
TEXT

    my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(
        mode => MODE_APPEND,
        content => \$content,
    );

    my $old_content = $handle->content;
    my $old_content_length = $handle->content_length;

    my $str = 'This is new line';
    my $fmt = "%s!\n";
    my $new_line = sprintf($fmt, $str);

    my $out = $handle->PRINTF($fmt, $str);

    my $expected_content = $old_content.$new_line;
    my $new_content_length = $handle->content_length;

    is($handle->content, $expected_content, 'Content matches');
    isnt($old_content_length, $new_content_length, 'Content length is reseted');
    ok($out, 'PRINT method returned True');
}

sub test_PRINTF__wrong_mode: Test {
    my ($self) = @_;

    my $handle = $self->handle;

    eval {
        $handle->PRINTF('bla');
    };

    if (my $err = $@) {
        like($err, qr/opened only for input/, 'Exception is thrown');
    }
    else {
        fail('Exception is not thrown');
    }
}

sub test_set_content__ok: Test(3) {
    my $content = 'foo';
    my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(content => \$content);

    my $expected_content = 'spam';
    my $old_content_length = $handle->content_length;
    my $out = $handle->set_content($expected_content);
    my $new_content_length = $handle->content_length;

    is($handle->content, $expected_content, 'Content is updated');
    ok($out, "'set_content' method returned True");
    isnt($old_content_length, $new_content_length, 'Content length is reseted');
}

sub test_set_content__exception: Test {
    my ($self) = @_;

    eval {
        $self->handle->set_content();
    };

    if ($@) {
        pass('Excpetion is thrown');
    }
    else {
        fail('Exception is not thrown');
    }
}

sub test_reset_content_length: Test(3) {
    my ($self) = @_;

    my $content = 'A';
    my $handle = $self->handle;

    $handle->content_length; # init property
    $handle->{content} = \$content;

    my $expected_content_length = length($content);
    my $actual_content_length = $handle->content_length;

    isnt($actual_content_length, $expected_content_length, 'Content length is more than 0');

    my $out = $handle->reset_content_length();
    $actual_content_length = $handle->content_length;

    is($actual_content_length, $expected_content_length, 'Content length is reseted');
    ok($out, "'reset_content_length' method returned True");
}

sub test_mode__default: Test {
    my ($self) = @_;

    my $actual = $self->handle->mode;

    is($actual, MODE_INPUT, 'MODE matches');
}

sub test_mode__custom: Test {
    my $content = 'egg';
    my $expected = MODE_OUTPUT;
    my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(content => \$content, mode => $expected);

    my $actual = $handle->mode;

    is($actual, $expected, 'MODE matches');
}

sub test_has_input_mode: Test(5) {
    my $matrix = [
        {
            mode    => MODE_INPUT,
            is_true => 1,
            title   => 'input',
        },
        {
            mode    => MODE_OUTPUT,
            is_true => 0,
            title   => 'OUTPUT',
        },
        {
            mode    => MODE_APPEND,
            is_true => 0,
            title   => 'append',
        },
        {
            mode    => MODE_INPUT | MODE_OUTPUT,
            is_true => 1,
            title   => 'input & output',
        },
        {
            mode    => MODE_INPUT | MODE_APPEND,
            is_true => 1,
            title   => 'input & append',
        },
    ];

    foreach my $hr (@{$matrix}) {
        my $mode = $hr->{mode};
        my $content = 'input';
        my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(content => \$content, mode => $mode);
        my $is_true = $hr->{is_true};

        my $actual = $handle->has_input_mode();
        $actual = !$actual unless ($is_true);

        ok($actual, sprintf('Input MODE check returned %s if MODE is %s',
                $is_true ? 'True' : 'False',
                $hr->{title},
            ));
    }
}

sub test_has_output_mode {
    my $matrix = [
        {
            mode    => MODE_INPUT,
            is_true => 0,
            title   => 'input',
        },
        {
            mode    => MODE_OUTPUT,
            is_true => 1,
            title   => 'OUTPUT',
        },
        {
            mode    => MODE_APPEND,
            is_true => 0,
            title   => 'append',
        },
        {
            mode    => MODE_INPUT | MODE_OUTPUT,
            is_true => 1,
            title   => 'input & output',
        },
        {
            mode    => MODE_INPUT | MODE_APPEND,
            is_true => 0,
            title   => 'input & append',
        },
    ];

    foreach my $hr (@{$matrix}) {
        my $mode = $hr->{mode};
        my $content = 'output';
        my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(content => \$content, mode => $mode);
        my $is_true = $hr->{is_true};

        my $actual = $handle->has_output_mode();
        $actual = !$actual unless ($is_true);

        ok($actual, sprintf('Output MODE check returned %s if MODE is %s',
                $is_true ? 'True' : 'False',
                $hr->{title},
            ));
    }
}

sub test_has_append_mode {
    my $matrix = [
        {
            mode    => MODE_INPUT,
            is_true => 0,
            title   => 'input',
        },
        {
            mode    => MODE_OUTPUT,
            is_true => 0,
            title   => 'OUTPUT',
        },
        {
            mode    => MODE_APPEND,
            is_true => 1,
            title   => 'append',
        },
        {
            mode    => MODE_INPUT | MODE_OUTPUT,
            is_true => 0,
            title   => 'input & output',
        },
        {
            mode    => MODE_INPUT | MODE_APPEND,
            is_true => 1,
            title   => 'input & append',
        },
    ];

    foreach my $hr (@{$matrix}) {
        my $mode = $hr->{mode};
        my $append = 'append';
        my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(content => \$append, mode => $mode);
        my $is_true = $hr->{is_true};

        my $actual = $handle->has_append_mode();
        $actual = !$actual unless ($is_true);

        ok($actual, sprintf('Append MODE check returned %s if MODE is %s',
                $is_true ? 'True' : 'False',
                $hr->{title},
            ));
    }
}

#@property
#@method
#@returns Test::Mock::File::Handle
sub handle {
    my ($self) = @_;

    return $self->{handle};
}

1;
