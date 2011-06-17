package Baracus;
use Dancer qw( :syntax );

our $VERSION = '2.0.0';
my $apiver = "/api/v1";

#    set views => '/opt/Baracus/views';
#    set public => '/opt/Baracus/public';
#    set confdir => '/opt/Baracus';
#    set appdir => '/opt/Baracus';

use Dancer::Plugin::Database;
use Dancer::Logger::Syslog;

use Baracus::REST::Source  qw( :subs );
use Baracus::REST::User    qw( :subs );
use Baracus::REST::Host    qw( :subs );
use Baracus::REST::Power   qw( :subs );
use Baracus::REST::Storage qw( :subs );
#use Baracus::REST::Config  qw( :subs );
#use Baracus::REST::Macast  qw( :subs );
#use Baracus::REST::Do      qw( :subs );
#use Baracus::REST::Auth    qw( :subs );

set serializer => 'Mutable';

my $opts = {
            verbose    => 1,
            quiet      => 0,
            all        => 0,
            nolabels   => 0,
            debug      => 0,
            execname   => "",
            LASTERROR  => "",
            baXML      => 0,
            sqlfsOBJ   => 0,
            dbinit     => 0,
            dbname     => "baracus",
            dbrole     => "baracus",
            };

sub init_baracus_vars {

    var opts => $opts;

    unless ( $opts->{baXML} ) {
        use Baracus::Config qw( :vars );
        use Baracus::Source qw( :subs );
        $opts->{baXML} = &baxml_load_distros( $opts );
    }

    unless ( $opts->{sqlfsOBJ} ) {
        use Baracus::SqlFS;
        my $tmp = $opts->{debug} > 2 ? 1 : 0;
        $opts->{sqlfsOBJ} = Baracus::SqlFS->new
            ( 'dbh' => database,
              'debug' => $tmp
             ) or die "Unable to create new instance of SqlFS\n";
    }
debug "DEBUG: dbinit=$opts->{dbinit} \n";
    unless ( $opts->{dbinit} ) {
        use Baracus::DB;
        &Baracus::DB::startup() or die $opts->{LASTERROR};
        $opts->{dbinit} = 1;
        debug "DEBUG: init running again\n";
    }
}

##
## END db test

###########################################################################
##
## Source Routing

## Main verb REST stubs
my $source_verbs = {
                    'list'    => \&source_list,
                    'add'     => \&source_add,
                    'remove'  => \&source_remove,
                    'verify'  => \&source_verify,
                    'detail'  => \&source_detail,
                    'admin'   => \&source_admin,
                   };

sub source_wrapper() {
    my $verb   = shift;
    my $method = request->method;

    if ( request->{accept} eq 'text/xml' ) {
        header('Content-Type' => 'text/xml');
        $source_verbs->{$verb}( @_ );
    } elsif ( request->{accept} eq 'application/json' ) {
        header('Content-Type' => 'application/json');
        $source_verbs->{$verb}( @_ );
    } else {
        layout 'main';
        template "baracus_mesg", { user => session('user') };
    }
}

get  "$apiver/source/:filter"        => sub { &source_wrapper( "list" );    };
get  "$apiver/source/verify/:distro" => sub { &source_wrapper( "verify" );  };
get  "$apiver/source/detail/:distro" => sub { &source_wrapper( "detail" );  };
post "$apiver/source"                => sub { &source_wrapper( "add" );     };
del  "$apiver/source/:distro"        => sub { &source_wrapper( "remove" );  };
del  "$apiver/source/:distro/:extra" => sub { &source_wrapper( "remove" );  };
put  "$apiver/source"                => sub { &source_wrapper( "admin" );   };

###########################################################################
##
## Host Routing

my $host_verbs = {
                  'list'      => \&host_list,
                  'detail'    => \&host_detail,
                  'inventory' => \&host_inventory,
                  'add'       => \&host_add,
                  'remove'    => \&host_remove,
                  'admin'     => \&host_admin,
                 };

sub host_wrapper() {
    my $verb   = shift;
    my $method = request->method;

    if ( request->{accept} eq 'text/xml' ) {
        header('Content-Type' => 'text/xml');
        $host_verbs->{$verb}( @_ );
    } elsif ( request->{accept} eq 'application/json' ) {
        header('Content-Type' => 'application/json');
#status 406; return { error => "Here's an error", code => "27" };
        $host_verbs->{$verb}( @_ );
    } else {
        layout 'main';
        template "baracus_mesg", { user => session('user') };
    }
}

get  "$apiver/host/states/:filter"        => sub { var type => "states"; &host_wrapper( "list" );    };
get  "$apiver/host/nodes/:filter"         => sub { var type => "nodes"; &host_wrapper( "list" );     };
get  "$apiver/host/templates/:filter"     => sub { var type => "templates"; &host_wrapper( "list" ); };
get  "$apiver/host/detail/by-mac/:mac"    => sub { var bytype => "mac"; &host_wrapper( "detail" );   };
get  "$apiver/host/detail/by-host/:host"  => sub { var bytype => "host"; &host_wrapper( "detail" );  };
get  "$apiver/host/inventory/:node"       => sub { &host_wrapper( "inventory" );                     };
post "$apiver/host"                       => sub { &host_wrapper( "add" );                           };
del  "$apiver/host/by-mac/:mac"           => sub { var bytype => "mac"; &host_wrapper( "remove" );   };
del  "$apiver/host/by-host/:host"         => sub { var bytype => "host"; &host_wrapper( "remove" );  };
put  "$apiver/host"                       => sub { &host_wrapper( "admin" );                         };


###########################################################################
##
## Do Routing

my $do_verbs = {
                'build'      => \&do_build,
                'empty'      => \&do_empty,
                'inventory'  => \&do_inventory,
                'localboot'  => \&do_localboot,
                'netboot'    => \&do_netboot,
                'norescue'   => \&do_norescue,
                'rescue'     => \&do_rescue,
                'wipe'       => \&do_wipe,
               };

get '/do/build/:host'     => sub { $do_verbs->{'build'}( @_ );          };
get '/do/empty/:host'     => sub { $do_verbs->{'empty'}( @_ );          };
get '/do/inventory/:host' => sub { $do_verbs->{'inventory'}( @_ );      };
get '/do/localboot/:host' => sub { $do_verbs->{'localboot'}( @_ );      };
get '/do/netboot/:host'   => sub { $do_verbs->{'netboot'}( @_ );        };
get '/do/norescue/:host'  => sub { $do_verbs->{'norescue'}( @_ );       };
get '/do/rescue/:host'    => sub { $do_verbs->{'rescue'}( @_ );         };
get '/do/wipe/:host'      => sub { $do_verbs->{'wipe'}( @_ );           };

###########################################################################
##
## Config Routing

my $config_verbs = {
                    'list'    => \&config_list,
                    'add'     => \&config_add,
                    'update'  => \&config_update,
                    'export'  => \&config_export,
                    'detail'  => \&config_detail,
                    'remove'  => \&config_remove,
                   };

get '/config/list/:config'    => sub { $config_verbs->{'list'}( @_ );   };
get '/config/add/:config'     => sub { $config_verbs->{'add'}( @_ );    };
get '/config/update/:config'  => sub { $config_verbs->{'update'}( @_ ); };
get '/config/export/:config'  => sub { $config_verbs->{'export'}( @_ ); };
get '/config/detail/:config'  => sub { $config_verbs->{'deatil'}( @_ ); };
get '/config/remove/:config'  => sub { $config_verbs->{'remove'}( @_ ); };

###########################################################################
##
## Power Routing

my $power_verbs = {
                   'admin'   => \&power_admin,
                   'status'  => \&power_status,
                   'remove'  => \&power_remove,
                   'add'     => \&power_add,
                   'list'    => \&power_list,
                  };

sub power_wrapper() {
    my $verb = shift;
    my $method = request->method;

    if ( request->{accept} eq 'text/xml' ) {
        header('Content-Type' => 'text/xml');
        $power_verbs->{$verb}( @_ );
    } elsif ( request->{accept} eq 'application/json' ) {
        header('Content-Type' => 'application/json');
        $power_verbs->{$verb}( @_ );
    } else {
        layout 'main';
        template "baracus_mesg", { user => session('user') };
    }
}

get  "$apiver/power/nodes/:filter"        => sub { &power_wrapper( "list" );                         };
get  "$apiver/power/status/by-mac/:mac"   => sub { var bytype => "mac"; &power_wrapper( "status" );  };
get  "$apiver/power/status/by-host/:host" => sub { var bytype => "host"; &power_wrapper( "status" ); };
put  "$apiver/power"                      => sub { &power_wrapper( "admin" );                        };
post "$apiver/power"                      => sub { &power_wrapper( "add" );                          };
del  "$apiver/power/by-mac/:mac"          => sub { var bytype => "mac"; &power_wrapper( "remove" );  };
del  "$apiver/power/by-host/:host"        => sub { var bytype => "host"; &power_wrapper( "remove" ); };

###########################################################################
##
## Storage Routing

my $storage_verbs = {
                     'add'     => \&storage_add,
                     'remove'  => \&storage_remove,
                     'list'    => \&storage_list,
                     'detail'  => \&storage_detail,
                    };

sub storage_wrapper() {
    my $verb = shift;
    my $method = request->method;

    if ( request->{accept} eq 'text/xml' ) {
        header('Content-Type' => 'text/xml');
        $storage_verbs->{$verb}( @_ );
    } elsif ( request->{accept} eq 'application/json' ) {
        header('Content-Type' => 'application/json');
        $storage_verbs->{$verb}( @_ );
    } else {
        layout 'main';
        template "baracus_mesg", { user => session('user') };
    }
}

post "$apiver/storage"                   => sub { $storage_verbs->{'add'}( @_ );     };
del  "$apiver/storage/:storageid"        => sub { $storage_verbs->{'remove'}( @_ );  };
get  "$apiver/storage/:filter"           => sub { $storage_verbs->{'list'}( @_ );    };
get  "$apiver/storage/detail/:storageid" => sub { $storage_verbs->{'detail'}( @_ );  };

###########################################################################
##
## Repo Routing

my $repo_verbs = {
                  'create'  => \&repo_create,
                  'add'     => \&repo_add,
                  'remove'  => \&repo_remove,
                  'update'  => \&repo_update,
                  'verify'  => \&repo_verify,
                  'list'    => \&repo_list,
                  'detail'  => \&repo_detail,
                 };

get '/repo/create/:repo' => sub { $repo_verbs->{'create'}( @_ );      };
get '/repo/add/:repo'    => sub { $repo_verbs->{'add'}( @_ );         };
get '/repo/remove/:repo' => sub { $repo_verbs->{'remove'}( @_ );      };
get '/repo/update/:repo' => sub { $repo_verbs->{'update'}( @_ );      };
get '/repo/verify/:repo' => sub { $repo_verbs->{'verify'}( @_ );      };
get '/repo/list/:repo'   => sub { $repo_verbs->{'list'}( @_ );        };
get '/repo/detail/:repo' => sub { $repo_verbs->{'detail'}( @_ );      };

###########################################################################
##
## Repo Routing

my $log_verbs = {
                 'list'  => \&repo_list,
                };

get '/log/list/:type' => sub { $log_verbs->{'list'}( @_ );            };

###########################################################################
##
## Inventory Routing

my $inventory_verbs = {
                       'import' => \&inventory_import,
                       'list'   => \&inventory_list,
                       'remove' => \&inventory_remove,
                      };

get '/inventory/import/:mac' => sub { $inventory_verbs->{'import'}( @_ ); };
get '/inventory/list/:mac'   => sub { $inventory_verbs->{'list'}( @_ );   };
get '/inventory/remove/:mac' => sub { $inventory_verbs->{'remove'}( @_ ); };

###########################################################################
##
## GPXE Routing

my $gpxe_verbs = {
                  'env'            => \&gpxe_env,
                  'auto'           => \&gpxe_auto,
                  'boot'           => \&gpxe_boot,
                  'chain'          => \&gpxe_chain,
                  'built'          => \&gpxe_built,
                  'initrd'         => \&gpxe_initrd,
                  'initrd.baracus' => \&gpxe_initrd_baracus,
                  'inventory'      => \&gpxe_inventory,
                  'linux'          => \&gpxe_linux,
                  'linux.baracus'  => \&gpxe_linux_baracus,
                  'parm'           => \&gpxe_parm,
                  'pxelinux.0'     => \&gpxe_pxelinux_0,
                  'sanboot.c32'    => \&gpxe_sanboot_c32,
                  'startrom.0'     => \&gpxe_startrom_0,
                  'winst'          => \&gpxe_winst,
                  'wipe'           => \&gpxe_wipe,
                 };

get  '/ba/env'            => sub { $gpxe_verbs->{'env'}           };
post '/ba/auto'           => sub { $gpxe_verbs->{'auto'}           };
post '/ba/boot'           => sub { $gpxe_verbs->{'boot'}           };
post '/ba/chain'          => sub { $gpxe_verbs->{'chain'}          };
post '/ba/built'          => sub { $gpxe_verbs->{'built'}          };
post '/ba/initrd'         => sub { $gpxe_verbs->{'initrd'}         };
post '/ba/initrd.baracus' => sub { $gpxe_verbs->{'initrd_baracus'} };
put  '/ba/inventory'      => sub { $gpxe_verbs->{'inventory'}      };
post '/ba/linux'          => sub { $gpxe_verbs->{'linux'}          };
post '/ba/linux.baracus'  => sub { $gpxe_verbs->{'linux_baracus'}  };
post '/ba/parm'           => sub { $gpxe_verbs->{'parm'}           };
post '/ba/pxelinux.0'     => sub { $gpxe_verbs->{'pxelinux_0'}     };
post '/ba/sanboot.c32'    => sub { $gpxe_verbs->{'sanboot_c32'}    };
post '/ba/startrom.0'     => sub { $gpxe_verbs->{'startrom_0'}     };
post '/ba/winst'          => sub { $gpxe_verbs->{'winst'}          };
post '/ba/wipe'           => sub { $gpxe_verbs->{'wipe'}           };

###########################################################################
##
## User Routing

my $user_verbs = {
                    'list'    => \&user_list,
                    'add'     => \&user_add,
                    'remove'  => \&user_remove,
                    'update'  => \&user_update,
                    'verify'  => \&user_verify,
                    'enable'  => \&user_enable,
                    'disable' => \&user_disable,
                   };

sub user_wrapper() {
    my $verb = shift;
    my $template = shift;
    my $method = request->method;

    if ( request->{accept} eq 'text/xml' ) {
        to_xml( $user_verbs->{$verb}( @_ ) );
    } else {
        layout 'main';
        if ( ( $method eq "GET") && ( ! defined vars->{exec} ) ) {
            template "$template", { user => session('user') };
        } elsif ( ( $method eq "POST") || ( defined vars->{exec} ) ) {
            template "$template", { user => session('user'), data => $user_verbs->{$verb}( @_ ) };
        }
    }
}

get    '/user/list/:user'   => sub { var exec => ""; &user_wrapper( "list", "user_list" );      };
get    '/user/verify/:user' => sub { var exec => ""; &user_wrapper( "verify", "user_verify" );  };
get    '/user/add'            => sub { &user_wrapper( "add", "user_add" );                        };
post   '/user/add'            => sub { &user_wrapper( "add", "user_response" );                   };
get    '/user/remove'         => sub { &user_wrapper( "remove", "user_remove" );                  };
post   '/user/remove'         => sub { &user_wrapper( "remove", "user_response" );                };
get    '/user/update'         => sub { &user_wrapper( "update", "user_update" );                  };
post   '/user/update'         => sub { &user_wrapper( "update", "user_response" );                };
get    '/user/enable'         => sub { &user_wrapper( "update", "user_enable" );                  };
post   '/user/enable'         => sub { &user_wrapper( "enable", "user_response" );                };
get    '/user/disable'        => sub { &user_wrapper( "update", "user_disable" );                 };
post   '/user/disable'        => sub { &user_wrapper( "disable", "user_response" );               };

###########################################################################
##                                                                       ##
##                           NON-Verb Routing                            ##
##                                                                       ## 
###########################################################################

###########################################################################
##
## Main Page Placeholder

get '/' => sub {
    if ( session('user') ) {
        layout 'main';
        template 'main', { user => session('user') };
    } else {
        redirect '/login';
    }
};

###########################################################################
##
## Login Route

get '/login' => sub {
   # Display a login page; the original URL they requested is available as
   # vars->{requested_path} which is in a hidden field in login.tt
    my $login_url = request->uri_for('/login');
    if ($login_url->scheme() ne "https") {
        $login_url->scheme('https');
        redirect $login_url;
    }
 
    if ( params->{failed} ) {
        var status => "Login Failed";
    } else {
        var status => "";
    }
    layout 'login';
    template 'login', { path => vars->{requested_path}, status => vars->{status} };
};

post '/login' => sub {
    use Crypt::SaltedHash;
    my $user = database()->selectrow_hashref('select * from auth where username = ?', {}, params->{username} );

    if (!$user) {
        warning "Failed login for unrecognised user " . params->{username};
        redirect '/login?failed=1';
    } else {
        if (Crypt::SaltedHash->validate($user->{password}, params->{password})) {
            debug "Password correct";
            # Logged in successfully
            session user => $user->{username};
            redirect params->{requested_path} || '/';
        } else {
            debug("Login failed - password incorrect for " . params->{username});
            redirect '/login?failed=1';
        }
    }
};

###########################################################################
##
## Logout Route

get '/logout' => sub {
    session->destroy();
    if ( request->{accept} eq 'text/html' ) {
        redirect '/login';
    }
};

###########################################################################
##
## Default Route: Non-existant Path Handling

any qr{.*'} => sub {
    status 'not_found';
    template 'special_404', { path => request->path };
};

###########################################################################
##
## Global before processing

##
## Authentication Validation
before sub {

    init_baracus_vars();

    set serializer => 'Mutable';

    if (! session('user') && request->path_info !~ m{^/login}) {
        var requested_path => request->path_info;
        request->path_info('/login');
    }
};

true;

__END__
