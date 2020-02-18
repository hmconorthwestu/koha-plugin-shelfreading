package Koha::Plugin::Com::NULibrary::ShelfReading;

## It's good practice to use Modern::Perl
use Modern::Perl;
use strict;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use CGI qw ( -utf8 );
my $input = CGI->new;
my $bc = $input->param('bc');
my $barcode = $input->param('barcode');
use C4::Context;
use lib C4::Context->config("pluginsdir");
use C4::Auth;
use C4::Output;
use C4::Biblio;
use C4::Items;
use C4::Koha;
use C4::Circulation;
use C4::Reports::Guided;    #_get_column_defs
use C4::Charset;
use Koha::Biblios;
use Koha::AuthorisedValues;
use Koha::BiblioFrameworks;
use Koha::ClassSources;
use Koha::Items;
use List::MoreUtils qw( none );

# use Koha::Patron;
use Koha::DateUtils;
# use Koha::Libraries;
# use Koha::Patron::Categories;
# use Koha::Account;
# use Koha::Account::Lines;
# use MARC::Record;
use Cwd qw(abs_path);
use Mojo::JSON qw(decode_json);;
use URI::Escape qw(uri_unescape);
use LWP::UserAgent;

## Here we set our plugin version
our $VERSION = "{VERSION}";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Shelf Reading Plugin',
    author          => 'Hannah Co',
    date_authored   => '2020-01-28',
    date_updated    => "2020-01-28",
    minimum_version => '19.11.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin implements inventory features '
      . 'for shelf reading as items are scanned. ',
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

## The existance of a 'report' subroutine means the plugin is capable
## of running a report. This example report can output a list of patrons
## either as HTML or as a CSV file. Technically, you could put all your code
## in the report method, but that would be a really poor way to write code
## for all but the simplest reports
##sub report {
##    my ( $self, $args ) = @_;
##    my $cgi = $self->{'cgi'};

##    unless ( $cgi->param('output') ) {
##        $self->report_step1();
##    }
##    else {
##        $self->report_step2();
##    }
##}

## The existance of a 'tool' subroutine means the plugin is capable
## of running a tool. The difference between a tool and a report is
## primarily semantic, but in general any plugin that modifies the
## Koha database should be considered a tool
sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('bc') ) {
        $self->inventory1();
    }
    else {
        $self->inventory2();
    }

}

## If your plugin needs to add some CSS to the staff intranet, you'll want
## to return that CSS here. Don't forget to wrap your CSS in <style>
## tags. By not adding them automatically for you, you'll have a chance
## to include external CSS files as well!
sub intranet_head {
    my ( $self ) = @_;

##    return q|
##        <style>
##          body {
##            background-color: orange;
##          }
##        </style>
##    |;
}

## If your plugin needs to add some javascript in the staff intranet, you'll want
## to return that javascript here. Don't forget to wrap your javascript in
## <script> tags. By not adding them automatically for you, you'll have a
## chance to include other javascript files if necessary.
sub intranet_js {
    my ( $self ) = @_;

    return q|
        <script>console.log("Thanks for testing the shelf reading plugin!");</script>
    |;
}

## This method allows you to add new html elements to the catalogue toolbar.
## You'll want to return a string of raw html here, most likely a button or other
## toolbar element of some form. See bug 20968 for more details.
## sub intranet_catalog_biblio_enhancements_toolbar_button {
##    my ( $self ) = @_;
##
##    return q|
##       <a class="btn btn-default btn-sm" onclick="alert('Peace and long life');">
##          <i class="fa fa-hand-spock-o" aria-hidden="true"></i>
##          Live long and prosper
##        </a>
##    |;
##}

## If your tool is complicated enough to needs it's own setting/configuration
## you will want to add a 'configure' method to your plugin like so.
## Here I am throwing all the logic into the 'configure' method, but it could
## be split up like the 'report' method is.
## sub configure {
##    my ( $self, $args ) = @_;
##    my $cgi = $self->{'cgi'};
##
##    unless ( $cgi->param('save') ) {
##        my $template = $self->get_template({ file => 'configure.tt' });

        ## Grab the values we already have for our settings, if any exist
##        $template->param(
##            enable_opac_payments => $self->retrieve_data('enable_opac_payments'),
##            foo             => $self->retrieve_data('foo'),
##            bar             => $self->retrieve_data('bar'),
##           last_upgraded   => $self->retrieve_data('last_upgraded'),
##        );
##
##        $self->output_html( $template->output() );
##    }
##    else {
##        $self->store_data(
##            {
##                enable_opac_payments => $cgi->param('enable_opac_payments'),
##                foo                => $cgi->param('foo'),
##                bar                => $cgi->param('bar'),
##                last_configured_by => C4::Context->userenv->{'number'},
##            }
##        );
##        $self->go_home();
##    }
##}

## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
## sub install() {
##    my ( $self, $args ) = @_;
##
##    my $table = $self->get_qualified_table_name('mytable');
##
##    return C4::Context->dbh->do( "
##        CREATE TABLE IF NOT EXISTS $table (
##            `borrowernumber` INT( 11 ) NOT NULL
##        ) ENGINE = INNODB;
##    " );
## }

## This is the 'upgrade' method. It will be triggered when a newer version of a
## plugin is installed over an existing older version of a plugin
sub upgrade {
    my ( $self, $args ) = @_;

    my $dt = dt_from_string();
    $self->store_data( { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') } );

    return 1;
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;

##    my $table = $self->get_qualified_table_name('mytable');

##    return C4::Context->dbh->do("DROP TABLE IF EXISTS $table");
}

## These are helper functions that are specific to this plugin
## You can manage the control flow of your plugin any
## way you wish, but I find this is a good approach
sub inventory1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'inventory1.tt' });


    $self->output_html( $template->output() );
}

sub inventory2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'inventory2.tt' });
	
	my @barcodes;

	my $bc = $cgi->param('bc');
	# set date to log in datelastseen column
	my $datelastseen = '%Y-%m-%d';
	push ( @barcodes, ( $bc ) );

	$template->param( 'scanned_items' => \@barcodes );

    $self->output_html( $template->output() );
}



## API methods
# If your plugin implements API routes, then the 'api_routes' method needs
# to be implemented, returning valid OpenAPI 2.0 paths serialized as a hashref.
# It is a good practice to actually write OpenAPI 2.0 path specs in JSON on the
# plugin and read it here. This allows to use the spec for mainline Koha later,
# thus making this a good prototyping tool.

#sub api_routes {
#    my ( $self, $args ) = @_;

#    my $spec_str = $self->mbf_read('openapi.json');
#    my $spec     = decode_json($spec_str);

#    return $spec;
#}

#sub api_namespace {
#    my ( $self ) = @_;
    
#    return 'kitchensink';
#}

#sub static_routes {
#    my ( $self, $args ) = @_;

#    my $spec_str = $self->mbf_read('staticapi.json');
#    my $spec     = decode_json($spec_str);

#    return $spec;
#}

1;
