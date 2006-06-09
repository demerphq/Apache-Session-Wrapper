#!perl -w

use strict;

use Test::More tests => 4;
use Apache::Test qw(:withtestmore);
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

my $ua = Apache::TestRequest::user_agent( cookie_jar => {} );

my $res = GET '/TestApache__basic';
ok( $res->is_success, 'request succeeded' );
ok( $res->header('set-cookie'), 'response includes cookie' );
$res->header('set-cookie') =~ m{asw_cookie=([^;]+);};
my $val1 = $1;

$res = GET '/TestApache__basic';
$res->header('set-cookie') =~ m{asw_cookie=([^;]+);};
my $val2 = $1;

is( $val1, $val2, 'got the same cookie for each request' );
unlike( $res->content, qr/ERROR/, 'no error message in response' );
