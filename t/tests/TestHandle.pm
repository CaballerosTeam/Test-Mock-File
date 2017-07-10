package TestHandle;

use strict;
use warnings FATAL => 'all';
use parent 'TestCase';

use Test::More;

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

    $self->{handle} = Test::Mock::File::Handle->TIEHANDLE(content => $content);
    $self->{content} = $content;
}

sub tearDown: Test(teardown) {
    my ($self) = @_;

    $/ = $self->{old_line_separator};
}

sub test_prerequisites: Test {
    my ($self) = @_;

    isa_ok($self->handle, 'Test::Mock::File::Handle');
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
    my Test::Mock::File::Handle $handle = Test::Mock::File::Handle->TIEHANDLE(content => $expected_line);

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

#@property
#@method
#@returns Test::Mock::File::Handle
sub handle {
    my ($self) = @_;

    return $self->{handle};
}

1;
