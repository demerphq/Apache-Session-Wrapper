package Apache::Session::Wrapper;

use strict;

use vars qw($VERSION);

$VERSION = '0.15';

use base qw(Class::Container);

use Apache::Session 1.6;

use Exception::Class ( 'Apache::Session::Wrapper::Exception::NonExistentSessionID' =>
		       { description => 'A non-existent session id was used',
			 fields => [ 'session_id' ] },
                       'Apache::Session::Wrapper::Exception::Params' =>
		       { description => 'A non-existent session id was used',
                         alias => 'param_error' },
		     );

use Params::Validate 0.70;
use Params::Validate qw( validate SCALAR UNDEF BOOLEAN OBJECT );
Params::Validate::validation_options( on_fail => sub { param_error( join '', @_ ) } );


my %params =
    ( always_write =>
      { type => BOOLEAN,
	default => 1,
	descr => 'Whether or not to force a write before the session goes out of scope' },

      allow_invalid_id =>
      { type => BOOLEAN,
	default => 1,
	descr => 'Whether or not to allow a failure to find an existing session id' },

      param_name =>
      { type => SCALAR,
        optional => 1,
        depends => 'param_object',
	descr => 'Name of the parameter to use for session tracking' },

      param_object =>
      { type => OBJECT,
        optional => 1,
        can  => 'param',
	descr => 'Object which has a "param" method, to be used for getting the session id from a query string or POST argument' },

      use_cookie =>
      { type => BOOLEAN,
	default => 0,
	descr => 'Whether or not to use a cookie to track the session' },

      cookie_name =>
      { type => SCALAR,
	default => 'Apache-Session-Wrapper-cookie',
	descr => 'Name of cookie used by this module' },

      cookie_expires =>
      { type => UNDEF | SCALAR,
	default => '+1d',
	descr => 'Expiration time for cookies' },

      cookie_domain =>
      { type => UNDEF | SCALAR,
        optional => 1,
	descr => 'Domain parameter for cookies' },

      cookie_path =>
      { type => SCALAR,
	default => '/',
	descr => 'Path for cookies' },

      cookie_secure =>
      { type => BOOLEAN,
	default => 0,
	descr => 'Are cookies sent only for SSL connections?' },

      cookie_resend =>
      { type => BOOLEAN,
	default => 1,
	descr => 'Resend the cookie on each request?' },

      header_object =>
      { type => OBJECT,
        callbacks =>
        { 'header method' =>
          sub { $_[0]->can('err_header_out') || $_[0]->can('header_out' ) } },
        optional => 1,
        descr => 'An object that can be used to send cookies with' },

      class =>
      { type => SCALAR,
	descr => 'An Apache::Session class to use for sessions' },

      data_source =>
      { type => SCALAR,
	optional => 1,
	descr => 'The data source when using MySQL or PostgreSQL' },

      user_name =>
      { type => UNDEF | SCALAR,
        optional => 1,
	descr => 'The user name to be used when connecting to a database' },

      password =>
      { type => UNDEF | SCALAR,
	optional => 1,
	descr => 'The password to be used when connecting to a database' },

      table_name =>
      { type => UNDEF | SCALAR,
        optional => 1,
        descr => 'The table in which sessions are saved' },

      lock_data_source =>
      { type => SCALAR,
	optional => 1,
	descr => 'The data source when using MySQL or PostgreSQL' },

      lock_user_name =>
      { type => UNDEF | SCALAR,
        optional => 1,
	descr => 'The user name to be used when connecting to a database' },

      lock_password =>
      { type => UNDEF | SCALAR,
	optional => 1,
	descr => 'The password to be used when connecting to a database' },

      handle =>
      { type => OBJECT,
        optional => 1,
	descr => 'An existing database handle to use' },

      lock_handle =>
      { type => OBJECT,
        optional => 1,
	descr => 'An existing database handle to use' },

      commit =>
      { type => BOOLEAN,
        default => 1,
	descr => 'Whether or not to auto-commit changes to the database' },

      transaction =>
      { type => BOOLEAN,
	default => 0,
	descr => 'The Transaction flag for Apache::Session' },

      directory =>
      { type => SCALAR,
	optional => 1,
	descr => 'A directory to use when storing sessions' },

      lock_directory =>
      { type => SCALAR,
	optional => 1,
	descr => 'A directory to use for locking when storing sessions' },

      file_name =>
      { type => SCALAR,
	optional => 1,
	descr => 'A DB_File to use' },

      store =>
      { type => SCALAR,
	optional => 1,
	descr => 'A storage class to use with the Flex module' },

      lock =>
      { type => SCALAR,
	optional => 1,
	descr => 'A locking class to use with the Flex module' },

      generate =>
      { type => SCALAR,
	default => 'MD5',
	descr => 'A session generator class to use with the Flex module' },

      serialize =>
      { type => SCALAR,
	optional => 1,
	descr => 'A serialization class to use with the Flex module' },

      textsize =>
      { type => SCALAR,
	optional => 1,
	descr => 'A parameter for the Sybase storage module' },

      long_read_len =>
      { type => SCALAR,
	optional => 1,
	descr => 'A parameter for the Oracle storage module' },

      n_sems =>
      { type => SCALAR,
	optional => 1,
	descr => 'A parameter for the Semaphore locking module' },

      semaphore_key =>
      { type => SCALAR,
	optional => 1,
	descr => 'A parameter for the Semaphore locking module' },

      mod_usertrack_cookie_name =>
      { type => SCALAR,
	optional => 1,
	descr => 'The cookie name used by mod_usertrack' },

      save_path =>
      { type => SCALAR,
	optional => 1,
	descr => 'Path used by Apache::Session::PHP' },

    );

# What set of parameters are required for each session class.
# Multiple array refs represent multiple possible sets of parameters
my %ApacheSessionParams =
    ( Flex     => [ [ qw( store lock generate serialize ) ] ],
      MySQL    => [ [ qw( data_source user_name password
                          lock_data_source lock_user_name lock_password ) ],
		    [ qw( handle lock_handle ) ] ],
      Postgres => [ [ qw( data_source user_name password commit ) ],
		    [ qw( handle commit ) ] ],
      File     => [ [ qw( directory lock_directory ) ] ],
      DB_File  => [ [ qw( file_name lock_directory ) ] ],

      PHP      => [ [ qw( save_path ) ] ],
    );

@ApacheSessionParams{ qw( Informix Oracle Sybase ) } =
    ( $ApacheSessionParams{Postgres} ) x 3;

my %OptionalApacheSessionParams =
    ( MySQL    => [ [ qw( table_name ) ] ],
      Postgres => [ [ qw( table_name ) ] ],
      Informix => [ [ qw( long_read_len table_name ) ] ],
      Oracle   => [ [ qw( long_read_len table_name ) ] ],
      Sybase   => [ [ qw( textsize table_name ) ] ],
    );

my %ApacheSessionFlexParams =
    ( store =>
      { MySQL    => [ [ qw( data_source user_name password ) ],
		      [ qw( handle ) ] ],
	Postgres => $ApacheSessionParams{Postgres},
	File     => [ [ qw( directory ) ] ],
	DB_File  => [ [ qw( file_name ) ] ],
      },
      lock =>
      { MySQL     => [ [ qw( lock_data_source lock_user_name lock_password ) ],
		       [ qw( lock_handle ) ] ],
	File      => [ [ ] ],
	Null      => [ [ ] ],
	Semaphore => [ [ ] ],
      },
      generate =>
      { MD5          => [ [ ] ],
	ModUniqueId  => [ [ ] ],
	ModUsertrack => [ [ qw( mod_usertrack_cookie_name )  ] ],
      },
      serialize =>
      { Storable => [ [ ] ],
	Base64   => [ [ ] ],
	Sybase   => [ [ ] ],
	UUEncode => [ [ ] ],
      },
    );

__PACKAGE__->valid_params(%params);

@{ $ApacheSessionFlexParams{store} }{ qw( Informix Oracle Sybase ) } =
    ( $ApacheSessionFlexParams{store}{Postgres} ) x 3;

my %OptionalApacheSessionFlexParams =
    ( Sybase => { store => [ qw( textsize ) ] },
      Oracle => { store => [ qw( long_read_len ) ] },
    );

sub _studly_form
{
    my $string = shift;
    $string =~ s/(?:^|_)(\w)/\U$1/g;
    return $string;
}

my %StudlyForm =
    ( map { $_ => _studly_form($_) }
      map { ref $_ ? @$_ :$_ }
      map { @$_ }
      ( values %ApacheSessionParams ),
      ( values %OptionalApacheSessionParams ),
      ( map { values %{ $ApacheSessionFlexParams{$_} } }
	keys %ApacheSessionFlexParams ),
      ( map { values %{ $OptionalApacheSessionFlexParams{$_} } }
	keys %OptionalApacheSessionFlexParams ),
    );

# why Apache::Session does this I do not know
$StudlyForm{textsize} = 'textsize';

sub new
{

    my $class = shift;

    my $self = $class->SUPER::new(@_);

    $self->_check_session_params;
    $self->_set_session_params;

    if ( $self->{use_cookie} && ! ( $ENV{MOD_PERL} || $self->{header_object} ) )
    {
        param_error
            "The header_object parameter is required to use cookies outside of mod_perl";
    }

    eval "require Apache::Session::$self->{session_class_piece}";
    die $@ if $@;

    $self->_make_session;

    $self->_bake_cookie
        if $self->{use_cookie} && ! $self->{cookie_is_baked};

    return $self;
}

sub _check_session_params
{
    my $self = shift;

    $self->{session_class_piece} = $self->{class};
    $self->{session_class_piece} =~ s/^Apache::Session:://;

    my $sets = $ApacheSessionParams{ $self->{session_class_piece} }
	or param_error "Invalid session class: $self->{class}";

    $self->_check_sets( $sets, 'session', $self->{class} )
        if grep { @$_ } @$sets;

    if ( $self->{session_class_piece} eq 'Flex' )
    {
	foreach my $key ( keys %ApacheSessionFlexParams )
	{
	    my $subclass = $self->{$key};
	    my $sets = $ApacheSessionFlexParams{$key}{$subclass}
		or param_error "Invalid class for $key: $self->{$key}";

            $self->_check_sets( $sets, $key, $subclass )
                if grep { @$_ } @$sets;
	}
    }
}

sub _check_sets
{
    my $self = shift;
    my $sets = shift;
    my $type = shift;
    my $class = shift;

    my $matched = 0;
    foreach my $set (@$sets)
    {
        # Don't check for missing elements unless at least one element
        # is present.
        if ( grep { exists $self->{$_} } @$set )
        {
            $matched = 1;
        }
        else
        {
            next;
        }

        my @missing = grep { ! exists $self->{$_} } @$set;

        param_error "Some of the required parameters for your chosen $type class ($class) were missing: @missing."
            if @missing;
    }

    param_error "None of the required parameters for your chosen $type class ($class) were provided."
        unless $matched;

    return;
}

sub _set_session_params
{
    my $self = shift;

    my %params;

    $self->_sets_to_params
	( $ApacheSessionParams{ $self->{session_class_piece} },
	  \%params );

    $self->_sets_to_params
	( $OptionalApacheSessionParams{ $self->{session_class_piece} },
	  \%params );


    if ( $self->{session_class_piece} eq 'Flex' )
    {
	foreach my $key ( keys %ApacheSessionFlexParams )
	{
	    my $subclass = $self->{$key};
	    $params{ $StudlyForm{$key} } = $subclass;

	    $self->_sets_to_params
		( $ApacheSessionFlexParams{$key}{$subclass},
		  \%params );

	    $self->_sets_to_params
		( $OptionalApacheSessionFlexParams{$key}{$subclass},
		  \%params );
	}
    }

    $self->{params} = \%params;

    if ( $self->{use_cookie} )
    {
        if ( $ENV{MOD_PERL} )
        {
            eval { require Apache::Cookie };
            unless ($@)
            {
                $self->{cookie_class} = 'Apache::Cookie';
                $self->{new_cookie_args} = [ Apache->request ];
            }
        }

        unless ( $self->{cookie_class} )
        {
            require CGI::Cookie;
            $self->{cookie_class} = 'CGI::Cookie';
            $self->{new_cookie_args} = [];
        }
    }
}

sub _sets_to_params
{
    my $self = shift;
    my $sets = shift;
    my $params = shift;

    foreach my $set (@$sets)
    {
	foreach my $key (@$set)
	{
	    if ( exists $self->{$key} )
	    {
		$params->{ $StudlyForm{$key} } =
		    $self->{$key};
	    }
	}
    }
}

sub _make_session
{
    my $self = shift;
    my %p = validate( @_,
		      { session_id =>
			{ type => SCALAR,
                          optional => 1,
			},
		      } );

    return if
        defined $p{session_id} && $self->_try_session_id( $p{session_id} );

    my $id = $self->_get_session_id;
    return if defined $id && $self->_try_session_id($id);

    if ( defined $self->{param_name} )
    {
        my $id = $self->_get_session_id_from_args;

        return if defined $id && $self->_try_session_id($id);
    }

    if ( $self->{use_cookie} )
    {
        my $id = $self->_get_session_id_from_cookie;

        if ( defined $id && $self->_try_session_id($id) )
        {
            $self->{cookie_is_baked} = 1
                unless $self->{cookie_resend};

            return;
        }
    }

    # make a new session id
    $self->_try_session_id(undef);
}

# for subclasses
sub _get_session_id { return }

sub _get_session_id_from_args
{
    my $self = shift;

    return $self->{param_object}->param( $self->{param_name} );
}

sub _try_session_id
{
    my $self = shift;
    my $session_id = shift;

    return 1 if ( $self->{session} &&
                  defined $session_id &&
                  $self->{session_id} eq $session_id );

    my %s;
    {
	local $SIG{__DIE__};
	eval
	{
	    tie %s, "Apache::Session::$self->{session_class_piece}",
                $session_id, $self->{params};
	};

        if ($@)
        {
            $self->_handle_tie_error( $@, $session_id );
            return;
        }
    }

    untie %{ $self->{session} } if $self->{session};

    $self->{session} = \%s;
    $self->{session_id} = $s{_session_id};

    $self->{cookie_is_baked} = 0;

    return 1;
}

sub _get_session_id_from_cookie
{
    my $self = shift;

    my %c = $self->{cookie_class}->fetch;

    return $c{ $self->{cookie_name} }->value
        if exists $c{ $self->{cookie_name} };

    return undef;
}

sub _handle_tie_error
{
    my $self = shift;
    my $err = shift;
    my $session_id = shift;

    if ( $err =~ /Object does not exist/ )
    {
        return if $self->{allow_invalid_id};

        Apache::Session::Wrapper::Exception::NonExistentSessionID->throw
            ( error => "Invalid session id: $session_id",
              session_id => $session_id );
    }
    else
    {
        die $@;
    }
}

sub _bake_cookie
{
    my $self = shift;

    my $expires = shift || $self->{cookie_expires};

    $expires = undef if defined $expires && $expires =~ /^session$/i;

    my $domain = $self->{cookie_domain};

    my $cookie =
        $self->{cookie_class}->new
            ( @{ $self->{new_cookie_args} },
              -name    => $self->{cookie_name},
              -value   => $self->{session_id},
              -expires => $expires,
              ( defined $domain ?
                ( -domain  => $domain ) :
                ()
              ),
              -path    => $self->{cookie_path},
              -secure  => $self->{cookie_secure},
            );

    if ( $cookie->can('bake') )
    {
        # Apache::Cookie
        $cookie->bake;
    }
    else
    {
        my $header_object = $self->{header_object};
        my $meth = $header_object->can('err_header_out') ? 'err_header_out' : 'header_out';

        $header_object->$meth( 'Set-Cookie' => $cookie );
    }

    # always set this even if we skipped actually setting the cookie
    # to avoid resending it.  this keeps us from entering this method
    # over and over
    $self->{cookie_is_baked} = 1
        unless $self->{cookie_resend};
}

sub session
{
    my $self = shift;

    if ( ! $self->{session} || @_ )
    {
        $self->_make_session(@_);

        $self->_bake_cookie
            if $self->{use_cookie} && ! $self->{cookie_is_baked};
    }

    return $self->{session};
}

sub delete_session
{
    my $self = shift;

    return unless $self->{session};

    my $session = delete $self->{session};

    (tied %$session)->delete;

    delete $self->{session_id};

    $self->_bake_cookie('-1d') if $self->{use_cookie};
}

sub cleanup_session
{
    my $self = shift;

    if ( $self->{always_write} )
    {
	if ( $self->{session}->{___force_a_write___} )
	{
	    $self->{session}{___force_a_write___} = 0;
	}
	else
	{
	    $self->{session}{___force_a_write___} = 1;
	}
    }

    undef $self->{session};
}

sub DESTROY { $_[0]->cleanup_session }


1;

__END__

=head1 NAME

Apache::Session::Wrapper - A simple wrapper around Apache::Session

=head1 SYNOPSIS

 my $wrapper =
     Apache::Session::Wrapper->new( class  => 'MySQL',
                                    handle => $dbh,
                                    cookie_name => 'example-dot-com-cookie',
                                  );

 # will get an existing session from a cookie, or create a new session
 # and cookie if needed
 $wrapper->session->{foo} = 1;

=head1 DESCRIPTION

This module is a simple wrapper around Apache::Session which provides
some methods to simplify getting and setting the session id.

It can uses cookies to store the session id, or it can look in a
provided object for a specific parameter.  Alternately, you can simply
provide the session id yourself in the call to the C<session()>
method.

If you're using Mason, you should probably take a look at
C<MasonX::Request::WithApacheSession> first, which integrates this
module directly into Mason.

=head1 METHODS

This class provides the following public methods:

=over 4

=item * new

This method creates a new C<Apache::Session::Wrapper> object.

If the parameters you provide are not correct (wrong type, missing
parameters, etc.), this method throws an
C<Apache::Session::Wrapper::Exception::Params> exception.  You can
treat this as a string if you want.

=item * session

This method returns a hash tied to the C<Apache::Session> class.

This method accepts an optional "session_id" parameter.

=item * delete_session

This method deletes the existing session from persistent storage.  If
you are using the built-in cookie handling, it also deletes the cookie
in the browser.

=back

=head1 CONFIGURATION

This module accepts quite a number of parameters, most of which are
simply passed through to C<Apache::Session>.  For this reason, you are
advised to familiarize yourself with the C<Apache::Session>
documentation before attempting to configure this module.

=head2 Generic Parameters

=over 4

=item * class  =>  class name

The name of the C<Apache::Session> subclass you would like to use.

This module will load this class for you if necessary.

This parameter is required.

=item * always_write  =>  boolean

If this is true, then this module will ensure that C<Apache::Session>
writes the session.  If it is false, the default C<Apache::Session>
behavior is used instead.

This defaults to true.

=item * allow_invalid_id  =>  boolean

If this is true, an attempt to create a session with a session id that
does not exist in the session storage will be ignored, and a new
session will be created instead.  If it is false, a
C<Apache::Session::Wrapper::Exception::NonExistentSessionID> exception
will be thrown instead.

This defaults to true.

=back

=head2 Cookie-Related Parameters

=over 4

=item * use_cookie  =>  boolean

If true, then this module will use C<Apache::Cookie> or C<CGI::Cookie>
(as appropriate) to set and read cookies that contain the session id.

The cookie will be set again every time the client accesses a Mason
component unless the C<cookie_resend> parameter is false.

=item * cookie_name  =>  name

This is the name of the cookie that this module will set.  This
defaults to "Apache-Session-Wrapper-cookie".
Corresponds to the C<Apache::Cookie> "-name" constructor parameter.

=item * cookie_expires  =>  expiration

How long before the cookie expires.  This defaults to 1 day, "+1d".
Corresponds to the "-expires" parameter.

As a special case, you can set this value to "session" to have the
"-expires" parameter set to undef, which gives you a cookie that
expires at the end of the session.

=item * cookie_domain  =>  domain

This corresponds to the "-domain" parameter.  If not given this will
not be set as part of the cookie.

If it is undefined, then no "-domain" parameter will be given.

=item * cookie_path  =>  path

Corresponds to the "-path" parameter.  It defaults to "/".

=item * cookie_secure  =>  boolean

Corresponds to the "-secure" parameter.  It defaults to false.

=item * cookie_resend  =>  boolean

By default, this parameter is true, and the cookie will be sent for
I<every request>.  If it is false, then the cookie will only be sent
when the session is I<created>.  This is important as resending the
cookie has the effect of updating the expiration time.

=item * header_object => object

When running outside of mod_perl, you must provide an object to which
the cookie header can be added.  This object must provide either an
C<err_header_out()> or C<header_out()> method.

Under mod_perl, this will default to the object returned by C<<
Apache->request >>.

=back

=head2 Query/POST-Related Parameters

=over 4

=item * param_name  =>  name

If set, then this module will first look for the session id in the
object specified via "param_object".  This parameter determines the
name of the parameter that is checked.

If you are also using cookies, then the module checks the param object
I<first>, and then it checks for a cookie.

The session id is available from C<< $m->session->{_session_id} >>.

=item * param_object  =>  object

This should be an object that provides a C<param()> method.  This
object will be checked to see if it contains the parameter named in
"params_name".  This object will probably be a C<CGI.pm> or
C<Apache::Request> object, but it doesn't have to be.

=back

=head2 Apache::Session-related Parameters

These parameters are simply passed through to C<Apache::Session>.

=over 4

=item * data_source  =>  DSN

Corresponds to the C<DataSource> parameter passed to the DBI-related
session modules.

=item * user_name  =>  user name

Corresponds to the C<UserName> parameter passed to the DBI-related
session modules.

=item * password  =>  password

Corresponds to the C<Password> parameter passed to the DBI-related
session modules.

=item * handle =>  DBI handle

Corresponds to the C<Handle> parameter passed to the DBI-related
session modules.  This cannot be set via the F<httpd.conf> file,
because it needs to be an I<actual Perl variable>, not the I<name> of
that variable.

=item * table_name  =>  table name

Corresponds to the C<TableName> paramaeter passed to DBI-related
modules.

=item * lock_data_source  =>  DSN

Corresponds to the C<LockDataSource> parameter passed to
C<Apache::Session::MySQL>.

=item * lock_user_name  =>  user name

Corresponds to the C<LockUserName> parameter passed to
C<Apache::Session::MySQL>.

=item * lock_password  =>  password

Corresponds to the C<LockPassword> parameter passed to
C<Apache::Session::MySQL>.

=item * lock_handle  =>  DBI handle

Corresponds to the C<LockHandle> parameter passed to the DBI-related
session modules.  As with the C<handle> parameter, this cannot
be set via the F<httpd.conf> file.

=item * commit =>  boolean

Corresponds to the C<Commit> parameter passed to the DBI-related
session modules.

=item * transaction  =>  boolean

Corresponds to the C<Transaction> parameter.

=item * directory  =>  directory

Corresponds to the C<Directory> parameter passed to
C<Apache::Session::File>.

=item * lock_directory  =>  directory

Corresponds to the C<LockDirectory> parameter passed to
C<Apache::Session::File>.

=item * file_name  =>  file name

Corresponds to the C<FileName> parameter passed to
C<Apache::Session::DB_File>.

=item * store  =>  class

Corresponds to the C<Store> parameter passed to
C<Apache::Session::Flex>.

=item * lock  =>  class

Corresponds to the C<Lock> parameter passed to
C<Apache::Session::Flex>.

=item * generate  =>  class

Corresponds to the C<Generate> parameter passed to
C<Apache::Session::Flex>.

=item * serialize  =>  class

Corresponds to the C<Serialize> parameter passed to
C<Apache::Session::Flex>.

=item * textsize  =>  size

Corresponds to the C<textsize> parameter passed to
C<Apache::Session::Sybase>.

=item * long_read_len  =>  size

Corresponds to the C<LongReadLen> parameter passed to
C<Apache::Session::MySQL>.

=item * n_sems  =>  number

Corresponds to the C<NSems> parameter passed to
C<Apache::Session::Lock::Semaphore>.

=item * semaphore_key  =>  key

Corresponds to the C<SemaphoreKey> parameter passed to
C<Apache::Session::Lock::Semaphore>.

=item * mod_usertrack_cookie_name  =>  name

Corresponds to the C<ModUsertrackCookieName> parameter passed to
C<Apache::Session::Generate::ModUsertrack>.

=item * save_path  =>  path

Corresponds to the C<SavePath> parameter passed to
C<Apache::Session::PHP>.

=back

=head1 HOW COOKIES ARE HANDLED

When run under mod_perl, this module attempts to first use
C<Apache::Cookie> for cookie-handling.  Otherwise it uses
C<CGI::Cookie> as a fallback.

If it ends up using C<CGI::Cookie> then must provide a "header_object"
parameter.  The module calls C<err_header_out()> or C<header_out()> on
the provided object, using the former if it's available.

=head1 SUBCLASSING

This class provides a simply hook for subclasses.  Before trying to
get a session id from the URL or cookie, it calls a method named
C<_get_session_id()>.  In this class, that method is a no-op, but you
can override this in a subclass.

This class is a C<Class::Container> subclass, so if you accept
additional constructor parameters, you should declare them via the
C<valid_params()> method.

=head1 SUPPORT

As can be seen by the number of parameters above, C<Apache::Session>
has B<way> too many possibilities for me to test all of them.  This
means there are almost certainly bugs.

Please submit bugs to the CPAN RT system at
http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Apache%3A%3ASession%3A%3AWrapper
or via email at bug-apache-session-wrapper@rt.cpan.org.

Support questions can be sent to me at my email address, shown below.

=head1 AUTHOR

Dave Rolsky, <autarch@urth.org>

=cut
