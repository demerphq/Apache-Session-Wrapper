use strict;
use Module::Build;

my $build_pkg =
    eval { require Apache::TestMB } ? 'Apache::TestMB' : 'Module::Build';

my $build =
    $build_pkg->new
        ( module_name     => 'Apache::Session::Wrapper',
          license         => 'perl',
          sign            => 1,
          requires        => { 'Apache::Session'  => 1.6,
                               'Class::Container' => 0,
                               'Exception::Class' => 0,
                               'Params::Validate' => 0.70,
                             },
          build_requires  => { 'Apache::Test'     => 0 },
          create_makefile_pl => 'passthrough',
        );

$build->create_build_script;
$build->add_to_cleanup( 't/session' );
