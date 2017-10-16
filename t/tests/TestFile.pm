package TestFile;

use strict;
use warnings FATAL => 'all';
use parent 'TestCase';

use Test::More;
use Sub::Override;
use Scalar::Util;

use Test::Mock::File;
use Test::Mock::File::Constant;


sub setUp: Test(setup) {
    my ($self) = @_;

    $self->{file} = Test::Mock::File->new();
}

sub test_new__no_instance: Test(2) {
    my $override = Sub::Override->new();
    $override->replace('Test::Mock::File::_get_instance', sub { return });

    my $expected_class = 'Test::Mock::File';
    $override->replace('Test::Mock::File::_set_instance', sub {
            my (undef, $instance) = @_;

            isa_ok($instance, $expected_class, sprintf('Instance of %s returned', $expected_class));
        });

    my $instance = Test::Mock::File->new();
    isa_ok($instance, $expected_class, sprintf('Instance of %s returned', $expected_class));
}

sub test_new__instance_exists: Test {
    my $expected_instance = 'INSTANCE';

    my $override = Sub::Override->new();
    $override->replace('Test::Mock::File::_get_instance', sub { return $expected_instance });
    $override->replace('Test::Mock::File::_set_instance', sub { fail("Unexpected call of '_set_instance'") });

    my $actual_instance = Test::Mock::File->new();
    is($actual_instance, $expected_instance, 'Instance matches');
}

sub test_get_set_instance: Test(2) {
    my $expected_instance = bless({greeting => 'Hello'}, 'Test::Mock::File');

    my $out = Test::Mock::File->_set_instance($expected_instance);
    ok($out, "'_set_instance' method returned True");

    my $actual_instance = Test::Mock::File->_get_instance();
    is($actual_instance, $expected_instance, 'Instance matches');
}

sub test_set_instance__exception: Test(2) {
    eval {
        Test::Mock::File->_set_instance({identity => 'EMPTY'});
    };

    if ($@) {
        pass('Exception is thrown');
    }
    else {
        fail('Exception is not thrown');
    }

    my $instance = bless({identity => 'handle'}, 'Test::Mock::File::Handle');
    eval {
        Test::Mock::File->_set_instance($instance);
    };

    if ($@) {
        pass('Exception is thrown');
    }
    else {
        fail('Exception is not thrown');
    }
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

    my $expected = 'MODE_APPEND';
    my $override = Sub::Override->new();
    $override->replace('Test::Mock::File::_parse_mode', sub { return $expected });

    my $fh;
    my $actual = $self->file->_get_mode(\$fh, '>>', '/path/to/some/file');

    is($actual, $expected, 'MODE matches');
}

sub test_get_mode__2_arguments: Test {
    my ($self) = @_;

    my $override = Sub::Override->new();
    $override->replace('Test::Mock::File::_parse_mode', sub {
            fail("Unexpected call of '_parse_mode'");
        });

    my $fh;
    my $actual = $self->file->_get_mode(\$fh, '/path/to/another/file');

    is($actual, Test::Mock::File::Constant::MODE_INPUT, 'MODE matches');
}

sub test_mock__wo_file_path: Test {
    my ($self) = @_;

    eval {
        $self->file->mock(undef, content => '');
    };

    if ($@) {
        pass('Exception thrown');
    }
    else {
        fail('Exception is not thrown');
    }
}

sub test_mock__wo_content: Test(3) {
    my ($self) = @_;

    my $file_path = '/root/info.txt';
    my $file = $self->file;
    $file->mock($file_path);

    my $assets = $file->_get_mock_file_assets($file_path);
    my $key = 'content';

    ok(defined($assets->{$key}), "Key 'content' exists and defined in assets HASH");
    is(ref($assets->{$key}), 'SCALAR', "'content' is a SCALAR ref");
    is(${$assets->{$key}}, '', 'Content is an empty string');
}

sub test_mock__w_content: Test(3) {
    my ($self) = @_;

    my $file_path = '/root/information.txt';
    my $file = $self->file;
    my $expected_content = 'SOME STRING';
    $file->mock($file_path, content => \$expected_content);

    my $assets = $file->_get_mock_file_assets($file_path);
    my $key = 'content';

    ok(defined($assets->{$key}), "Key 'content' exists and defined in assets HASH");
    is(ref($assets->{$key}), 'SCALAR', "'content' is a SCALAR ref");
    is(${$assets->{$key}}, $expected_content, 'Content matches');
}

sub test_dispatch_open__normal_open: Test {
    my ($self) = @_;

    my $override = Sub::Override->new();
    $override->replace('Test::Mock::File::_open', sub {
            fail("Unexpected call of '_open'");
        });

    eval {
        my $fh;
        $self->file->_dispatch_open(\$fh, '<', '/not/mocked/file') or do {
            pass('Looks like CORE::open called');
        };
    };

    if (my $err = $@) {
        fail(sprintf('Error: %s', $err));
    }
}

sub test_dispatch_open__no_filehandle: Test {
    my ($self) = @_;

    my $override = Sub::Override->new();
    $override->replace('Test::Mock::File::_open', sub {
            fail("Unexpected call of '_open'");
        });
    $override->replace('Test::Mock::File::_get_filehandle', sub { return });

    my $file = $self->file;
    $file->verbosity(0);

    eval {
        my $fh;
        $file->_dispatch_open(\$fh, '<', '/not/mocked/file') or do {
            pass('Looks like CORE::open called');
        };
    };

    if (my $err = $@) {
        fail(sprintf('Error: %s', $err));
    }
}

sub test_dispatch_open__no_mode: Test {
    my ($self) = @_;

    my $override = Sub::Override->new();
    $override->replace('Test::Mock::File::_open', sub {
            fail("Unexpected call of '_open'");
        });
    $override->replace('Test::Mock::File::_get_mode', sub { return });

    my $file = $self->file;
    $file->verbosity(0);

    eval {
        my $fh;
        $file->_dispatch_open(\$fh, '<', '/not/mocked/file') or do {
            pass('Looks like CORE::open called');
        };
    };

    if (my $err = $@) {
        fail(sprintf('Error: %s', $err));
    }
}

sub test_dispatch_open__no_file_path: Test {
    my ($self) = @_;

    my $override = Sub::Override->new();
    $override->replace('Test::Mock::File::_open', sub {
            fail("Unexpected call of '_open'");
        });
    $override->replace('Test::Mock::File::_get_file_path', sub { return });

    my $file = $self->file;
    $file->verbosity(0);

    eval {
        my $fh;
        $file->_dispatch_open(\$fh, '<', '/not/mocked/file') or do {
            pass('Looks like CORE::open called');
        };
    };

    if (my $err = $@) {
        fail(sprintf('Error: %s', $err));
    }
}

sub test_dispatch_open__mock_open: Test {
    my ($self) = @_;

    my $override = Sub::Override->new();
    $override->replace('Test::Mock::File::_is_mocked', sub { return 1 });
    $override->replace('Test::Mock::File::_get_mock_file_assets', sub { return {foo => 'egg'} });
    $override->replace('Test::Mock::File::_open', sub {
            pass("Looks like a mocked 'open' called");
            return 1;
        });

    eval {
        my $fh;
        $self->file->_dispatch_open(\$fh, '<', '/mocked/file') or do {
            die("Can't open mocked file");
        };
    };

    if (my $err = $@) {
        fail($err);
    }
}

sub test_get_filehandle: Test {
    my ($self) = @_;

    my $expected = 'FILEHANDLE';
    my $actual = $self->file->_get_filehandle($expected, 'MODE', 'FILE PATH');

    is($actual, $expected, 'Filehandle matches');
}

sub test_get_file_path__2_arguments: Test {
    my ($self) = @_;

    my $expected = 'FILE PATH';
    my $actual = $self->file->_get_file_path('FILEHANDLE', $expected);

    is($actual, $expected, 'File path matches');
}

sub test_get_file_path__3_arguments: Test {
    my ($self) = @_;

    my $expected = 'FILE PATH';
    my $actual = $self->file->_get_file_path('FILEHANDLE', 'MODE', $expected);

    is($actual, $expected, 'File path matches');
}

sub test_is_mocked: Test(2) {
    my ($self) = @_;

    my $mocked_file_path = 'mocked/file/path';
    my $matrix = [
        {
            file_path => $mocked_file_path,
            value     => 1,
        },
        {
            file_path => 'not/mocked/file/path',
            value     => 0,
        }
    ];

    my $mock_files = {$mocked_file_path => {}};

    my $file = $self->file;
    $file->{mock_files} = $mock_files;

    foreach my $hr (@{$matrix}) {
        my $actual = $file->_is_mocked($hr->{file_path});
        $actual = !$actual unless ($hr->{value});

        ok($actual, 'Is mocked flag matches');
    }
}

sub test_get_mock_file_assets: Test {
    my ($self) = @_;

    my $mocked_file_path = 'mocked/file/path';
    my $expected_assets = {foo => 'spam', egg => 100};
    my $mock_files = {$mocked_file_path => $expected_assets};

    my $file = $self->file;
    $file->{mock_files} = $mock_files;

    my $actual_assets = $file->_get_mock_file_assets($mocked_file_path);

    is($actual_assets, $expected_assets, 'Assets match');
}

sub test_get_set_verbosity: Test(2) {
    my ($self) = @_;

    my $file = $self->file;
    my $expected = 58;

    ok($file->verbosity($expected), "Method 'verbosity' returned True");
    is($file->verbosity, $expected, 'Verbosity level matches');
}

sub test_open: Test(2) {
    my ($self) = @_;

    my ($filehandle, $content);
    my $out = $self->file->_open(\$filehandle, content => \$content);

    ok($out, "Method '_open' returned True");
    ok(Scalar::Util::openhandle($filehandle), 'Filehandle is opened');
}

#@property
#@method
#@returns Test::Mock::File
sub file {
    my ($self) = @_;

    return $self->{file};
}

1;
