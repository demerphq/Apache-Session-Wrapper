#!/usr/bin/perl -w

use strict;

use File::Path;
use File::Spec;

use Test::More tests => 13;

use_ok('Apache::Session::Wrapper');

my %params =
    ( class     => 'Flex',
      store     => 'File',
      lock      => 'Null',
      generate  => 'MD5',
      serialize => 'Storable',
    );

foreach ( [ directory => 'Apache-Session-Wrapper-sessions-test' ],
        )
{
    my $dir = File::Spec->catfile( File::Spec->tmpdir, $_->[1] );
    mkpath($dir);

    $params{ $_->[0] } = $dir;
}

# will be used below in various ways
use Apache::Session::Flex;
my %session;
tie %session, 'Apache::Session::Flex', undef,
    { Store     => 'File',
      Lock      => 'Null',
      Generate  => 'MD5',
      Serialize => 'Storable',
      Directory => $params{directory},
    };
$session{bar}{baz} = 1;
my $id = $session{_session_id};
untie %session;

{
    my $w = Apache::Session::Wrapper->new(%params);

    ok( tied %{ $w->session }, 'session is a tied thing' );
    isa_ok( tied %{ $w->session }, 'Apache::Session' );
}

{
    my $w = Apache::Session::Wrapper->new(%params);

    $w->session( session_id => $id )->{foo} = 'bar';
}

{
    my $w = Apache::Session::Wrapper->new(%params);

    is( $w->session( session_id => $id )->{foo}, 'bar',
        'stored a value in the session' );
}

{
    my $w = Apache::Session::Wrapper->new(%params);

    eval { $w->session( session_id => 'abcdef' ) };

    ok( ! $@, 'invalid session id is allowed by default' );
}

{
    my $w = Apache::Session::Wrapper->new( %params, allow_invalid_id => 0 );

    eval { $w->session( session_id => 'abcdef' ) };
    my $e = $@;

    ok( $e, 'invalid session id caused an error' );
    isa_ok( $e, 'Apache::Session::Wrapper::Exception::NonExistentSessionID' );
}

{
    my $w = Apache::Session::Wrapper->new(%params);

    $w->session( session_id => $id )->{bar}{baz} = 50;

    is( $w->session( session_id => $id )->{bar}{baz}, 50,
        'always write - in memory value' );
}

{
    my $w = Apache::Session::Wrapper->new(%params);

    is( $w->session( session_id => $id )->{bar}{baz}, 50,
        'always write - stored value' );
}


{
    my $w = Apache::Session::Wrapper->new( %params, always_write => 0 );

    $w->session( session_id => $id )->{bar}{baz} = 100;

    is( $w->session( session_id => $id )->{bar}{baz}, 100,
        'always write is off - in memory value' );
}

{
    my $w = Apache::Session::Wrapper->new( %params, always_write => 0 );

    is( $w->session( session_id => $id )->{bar}{baz}, 50,
        'always write is off - stored value' );
}

{
    my $w = Apache::Session::Wrapper->new( %params, always_write => 0 );

    $w->session( session_id => $id )->{quux} = 100;

    $w->delete_session;

    is( $w->session( session_id => $id )->{quux}, undef,
        'session is empty after delete_session' );
}

rmtree( $params{directory} );

Test::More::diag( "\nIgnore the warning from Apache::Session::MySQL ..." );

eval { Apache::Session::Wrapper->new( class => 'Flex',
                                      store     => 'MySQL',
                                      lock      => 'Null',
                                      generate  => 'MD5',
                                      serialize => 'Storable',
                                      data_source => 'foo',
                                      user_name   => 'foo',
                                      password    => 'foo',
                                    ) };
unlike( $@, qr/parameters/ );
