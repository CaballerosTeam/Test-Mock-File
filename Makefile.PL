use strict;
use warnings;
use 5.010001;

use ExtUtils::MakeMaker 6.64;

WriteMakefile(
    NAME          => 'Test::Mock::File',
    VERSION_FROM  => 'lib/Test/Mock/File.pm',
    TEST_REQUIRES => {
        'Test::Class'   => 0.41,
        'Sub::Override' => 0.09,
    },
    ($] >= 5.005
        ? (
            ABSTRACT_FROM => 'lib/Test/Mock/File.pm',
            AUTHOR        => 'Sergey Yurzin <jurzin.s@gmail.com>'
        )
        : ()
    ),
    META_MERGE    => {
        'meta-spec' => {
            version => 2
        },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/CaballerosTeam/Test-Mock-File.git',
                web  => 'https://github.com/CaballerosTeam/Test-Mock-File',
            },
            bugtracker => {
                web    => 'https://github.com/CaballerosTeam/Test-Mock-File/issues',
                mailto => 'jurzin.s@gmail.com',
            },
        },
    },
);
