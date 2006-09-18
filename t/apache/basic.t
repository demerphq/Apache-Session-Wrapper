#!perl -w

use strict;

use Test::More tests => 6;
use Apache::Test qw(:withtestmore);
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

my $ua = Apache::TestRequest::user_agent( cookie_jar => {} );

{
    my $res = GET '/TestApache__basic';
    ok( $res->is_success, 'request succeeded' );
    ok( $res->header('set-cookie'), 'response includes cookie' );

    my ($cookie_val1) = ( $res->header('set-cookie') =~ m{asw_cookie=([^;]+);} );

    $res = GET '/TestApache__basic';
    $res->header('set-cookie') =~ m{asw_cookie=([^;]+);};
    my ($cookie_val2) = ( $res->header('set-cookie') =~ m{asw_cookie=([^;]+);} );

    is( $cookie_val1, $cookie_val2, 'got the same cookie for each request' );
    unlike( $res->content, qr/ERROR/, 'no error message in response' );
}

{
    my $res = GET '/TestApache__basic?delete=1';
    like( $res->header('set-cookie'), qr/asw_cookie=(?:;|\z)/,
          'no value in cookie when deleting' );
    unlike( $res->content, qr/ERROR/, 'no error message in response' );
}
