use strict;

use Module::Build;

my %requires;
eval { require mod_perl };
if ( $@ || $^O =~ /mac|darwin/ )
{
    $requires{'CGI::Cookie'} = 0;
}
else
{
    $requires{'Apache::Cookie'} = 0;
}

Module::Build->new
    ( module_name     => 'Apache::Session::Wrapper',
      license         => 'perl',
      sign            => 1,
      requires        => { 'Apache::Session'  => 1.6,
                           'Exception::Class' => 0,
                           'Params::Validate' => 0.70,
                           %requires,
                         },
      create_makefile_pl => 'passthrough',
    )->create_build_script;
