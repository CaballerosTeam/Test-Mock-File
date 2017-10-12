package TestFunctional;

use strict;
use warnings FATAL => 'all';
use parent 'TestCase';

use Cwd;
use File::Basename;
use Scalar::Util;

use Test::More;


sub setUp: Test(setup) {
    my ($self) = @_;

    $self->{mock_file} = Test::Mock::File->new();
}

sub test_read_file__ok: Test {
    my ($self) = @_;

    my $file_path = 'foo/spam.txt';
    my $expected_content = <<TEXT;
bla-bla text
TEXT

    $self->mock_file->mock($file_path, content => $expected_content);

    open(my $fh, '<', $file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    my $actual_content = <$fh>;

    close($fh);

    is($actual_content, $expected_content, 'File content match');
}

sub test_read_file__handle_is_closed: Test {
    my ($self) = @_;

    my $file_path = 'foo/egg.log';
    $self->mock_file->mock($file_path, content => '');

    open(my $fh, '<', $file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    close($fh);

    eval {
        <$fh>;
    };

    if (my $err = $@) {
        like($err, qr/readline\(\) on closed filehandle/, 'Exception is thrown');
    }
    else {
        fail('Exception is not thrown');
    }
}

sub test_read_file__read_real_file_in_parallel: Test(2) {
    my ($self) = @_;

    my $mock_file_path = 'the/simpsons';
    my $expected_mock_content = <<TEXT;
Homer Simpson
TEXT

    $self->mock_file->mock($mock_file_path, content => $expected_mock_content);

    open(my $mock_fh, '<', $mock_file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    my $package = 'TestCase';
    my $file_name = sprintf('%s.pm', $package);
    my $self_path = dirname(Cwd::realpath(__FILE__));
    my $file_path = join('/', $self_path, $file_name);
    
    open(my $fh, '<', $file_path) or do {
        fail(sprintf("Can't open file: %s: %s", $file_path, $!));
        return;
    };
    
    my $actual_real_content = readline($fh);
    my $actual_mock_content = readline($mock_fh);

    like($actual_real_content, qr/package $package/, 'Real content matches');
    is($actual_mock_content, $expected_mock_content, 'Mock content matches');

    close($fh);
    close($mock_fh);
}

sub test_read_file__whole_file: Test {
    my ($self) = @_;

    my $file_path = 'foo/multiline.txt';
    my $expected_content = <<TEXT;
One
Two
Three
Four
TEXT

    $self->mock_file->mock($file_path, content => $expected_content);

    open(my $fh, '<', $file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    my $actual_content;
    {
        local $/ = undef;
        $actual_content = <$fh>;
    }

    close($fh);

    is($actual_content, $expected_content, 'File content match');
}

sub test_read_file__wrong_mode: Test {
    my ($self) = @_;

    my $file_path = 'output_mode.conf';
    $self->mock_file->mock($file_path, content => 'bla');

    open(my $fh, '>', $file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    eval {
        readline($fh);
    };

    if (my $err = $@) {
        like($err, qr/Filehandle opened only for output/, 'Exception is thrown');
    }
    else {
        fail('Exception is not thrown');
    }

    close($fh);
}

sub test_fileno: Test(5) {
    my ($self) = @_;

    my $file_path = 'spam.conf';
    $self->mock_file->mock($file_path, content => 'bla');

    open(my $this, '<', $file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    open(my $that, '<', $file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    my ($this_fileno, $that_fileno) = (fileno($this), fileno($that));

    isnt($this_fileno, -1, 'File descriptor for a filehandle not -1');
    isnt($that_fileno, -1, 'File descriptor for a filehandle not -1');
    isnt($this_fileno, $that_fileno, 'File descriptors to the same file is not equal');

    close($this);

    $this_fileno = fileno($this);
    is($this_fileno, undef, 'Undefined returned if filehandle is closed');

    $that_fileno = fileno($that);
    ok(Scalar::Util::looks_like_number($that_fileno), 'Another filehandle still open');
}

sub test_write_file__ok: Test {
    my ($self) = @_;

    my $file_name = 'write.log';
    my $content = 'spam';
    $self->mock_file->mock($file_name, content => \$content);

    my ($first_line, $second_line) = ("FIRST LINE\n", 'second_line');

    my $expected_content = sprintf(<<TEXT, $first_line, $second_line);
%s%s
TEXT

    open(my $output_fh, '>', $file_name) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    print $output_fh $first_line;

    open(my $append_fh, '>>', $file_name) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    printf $append_fh "%s\n", $second_line;

    close($append_fh);

    close($output_fh);

    is($content, $expected_content, 'Content matches');
}

sub test_write_file__sequential_addition: Test {
    my ($self) = @_;

    my $file_name = 'append.log';
    my $content = 'SPAM';
    my ($first_line, $second_line) = ("FIRST LINE\n", 'second_line');
    my $expected_content = sprintf(<<TEXT, $content, $first_line, $second_line);
%s%s%s
TEXT

    $self->mock_file->mock($file_name, content => \$content);

    open(my $append_fh, '>>', $file_name) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    print $append_fh $first_line;

    printf $append_fh "%s\n", $second_line;

    close($append_fh);

    is($content, $expected_content, 'Content matches');
}

sub test_write_file__to_certain_position: Test {
    my ($self) = @_;

    my $file_name = 'seek.log';
    my $content_pattern = 'Sp%sm';
    my ($before, $after) = (qw/A a/);
    my $content = sprintf($content_pattern, $before);

    $self->mock_file->mock($file_name, content => \$content);

    open(my $seek_fh, '>', $file_name) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    seek($seek_fh, 2, Fcntl::SEEK_SET);

    print $seek_fh $after;

    close($seek_fh);

    my $expected_content = sprintf($content_pattern, $after);

    is($content, $expected_content, 'Content matches');
}

sub test_write_file__handle_is_closed: Test(2) {
    my ($self) = @_;

    my $file_path = 'foo/egg.log';
    $self->mock_file->mock($file_path, content => '');

    open(my $fh, '>', $file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    close($fh);

    eval {
        print $fh 'bla-bla';
    };

    if (my $err = $@) {
        like($err, qr/print\(\) on closed filehandle/, 'Exception is thrown');
    }
    else {
        fail('Exceptioin is not thrown');
    }

    eval {
        printf $fh '- %s -', 'bla-bla';
    };

    if (my $err = $@) {
        like($err, qr/print\(\) on closed filehandle/, 'Exception is thrown');
    }
    else {
        fail('Exception is not thrown');
    }
}

sub test_write_file__wrong_mode: Test {
    my ($self) = @_;

    my $file_path = 'input_mode.conf';
    $self->mock_file->mock($file_path, content => 'bla');

    open(my $fh, '<', $file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    eval {
        print $fh 'foo';
    };

    if (my $err = $@) {
        like($err, qr/Filehandle opened only for input/, 'Exception is thrown');
    }
    else {
        fail('Exception is not thrown');
    }

    close($fh);
}

#@property
#@returns Test::Mock::File
#@method
sub mock_file {
    my ($self) = @_;

    return $self->{mock_file};
}

1;
