package Koha::Plugin::Com::NULibrary::ShelfReading;

## It's good practice to use Modern::Perl
use Modern::Perl;
use strict;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use CGI qw ( -utf8 );
#use CGI::Session;
my $input = CGI->new;
my $bc = $input->param('bc');
my @oldBarcodes = $input->param('oldBarcodes');
use C4::Context;
use lib C4::Context->config("pluginsdir");
#use C4::Auth;
#use C4::Output;
#use C4::Biblio;
#use C4::Items;
use C4::Koha;
#use C4::Circulation;
#use C4::Reports::Guided;    #_get_column_defs
#use C4::Charset;
#use Koha::Biblios;
#use Koha::AuthorisedValues;
#use Koha::BiblioFrameworks;
#use Koha::ClassSources;
use Koha::Items;
#use List::MoreUtils qw( none );

# use Koha::Patron;
use Koha::DateUtils;
# use Koha::Libraries;
# use Koha::Patron::Categories;
# use Koha::Account;
# use Koha::Account::Lines;
# use MARC::Record;
#use Cwd qw(abs_path);
#use Mojo::JSON qw(decode_json);;
#use URI::Escape qw(uri_unescape);
#use LWP::UserAgent;
use Time::HiRes qw( time );
my $starta = time();
## Here we set our plugin version
our $VERSION = "{VERSION}";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Shelf Reading Plugin',
    author          => 'Hannah Co',
    date_authored   => '2020-01-28',
    date_updated    => "2020-01-28",
    minimum_version => '20.05.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin implements inventory features '
      . 'for shelf reading as barcodes are scanned. ',
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
    my $start = time();
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

	my @barcodes;
  my $duplicate;
  my @errorloop;


	my $count = 0;
	foreach $b (@oldBarcodes) {
    if ($b == $bc) {
      $duplicate = 1;
    } else {
  		my $item = Koha::Items->find({barcode => $b});
  		if ( $item ) {
        $item = $item->unblessed;
        if ($item->{itemnumber} eq "undef" || $item->{itemnumber} eq "" || $item->{itemnumber} < 1 ) {
          $item->{itemcallnumber} = $bc;
          $item->{itemnumber} = $bc;
          $item->{barcode} = $bc;
          $item->{problem} = "item not found";
        }
        push @barcodes, $item;
      }
		}
  	$count = $count + 1;
  }

  my $template = $self->get_template({ file => 'inventory2.tt' });

	#if ($cgi->cookie( 'barcodes' )) {
	#	@barcodes = $cgi->cookie( 'barcodes' );
	#	my $test = "cookie (barcodes) does exist";
	#	$template->param( 'test' => $test );
	#}
  unless ($duplicate == 1) {

  	# set date to log in datelastseen column
  	my $dt = dt_from_string();
  	my $datelastseen = $dt->ymd('-');
  	my $kohaitem = Koha::Items->find({barcode => $bc});
    my $item;
  	if ( $kohaitem ) {
  		my $item = $kohaitem->unblessed;
      if ($item->{itemnumber} eq "undef" || $item->{itemnumber} eq "" || $item->{itemnumber} < 1 ) {
        $item->{itemcallnumber} = $bc;
        $item->{itemnumber} = $bc;
        $item->{barcode} = $bc;
        $item->{problem} = "item not found";
        push @barcodes, $item;
      } else {
        # Modify date last seen for scanned items, remove lost status
        $kohaitem->set({ itemlost => 0, datelastseen => $datelastseen })->store;
        # update item hash accordingly
        $item->{itemlost} = 0;
        $item->{datelastseen} = $datelastseen;

        push @barcodes, $item;
      }
  	}
  }

	#ADD checks here for onloan, wrong homebranch, wrong ccode, withdrawn (don't need), cn_sort out of order
	my @sortbarcodes = @barcodes;
	for ( my $i = 0; $i < @sortbarcodes; $i++ ) {
		my $item = $sortbarcodes[$i];

      # item checked out/on loan
		if ($item->{onloan}) {
			$item->{problem} = "item is checked out";
      additemtobarcodes($item,@barcodes);
		} elsif ($item->{withdrawn}) {
			$item->{problem} = "item is marked as withdrawn";
      additemtobarcodes($item,@barcodes);
		} elsif ($item->{lost}) {
			$item->{problem} = "item is marked as lost";
      additemtobarcodes($item,@barcodes);
		} elsif ($item->{cn_sort} eq "" || $item->{cn_sort} eq "undef") {
      $item->{problem} = "item missing sorting call number";
      additemtobarcodes($item,@barcodes);
    }
    if ($item->{problem} eq "item not found") {
      # catch non-existent items so they don't disappear from shelfreading
      $item->{problem} = "item not in system";
      additemtobarcodes($item,@barcodes);
    }

    # compare to first item - check for wrong branch, wrong holding branch, wrong collection
    unless ( $i == 0 ) {
      my $firstitem = $sortbarcodes[0];
      if ($item->{homebranch} ne $firstitem->{homebranch}) {
        $item->{problem} = "Wrong branch library";
      }
      if ($item->{holdingbranch} ne $firstitem->{holdingbranch}) {
        $item->{problem} = "Wrong branch library";
      }
      if ($item->{location} ne $firstitem->{location}) {
        $item->{problem} = "Wrong shelving location";
      }
      # only check collection if shelving location ($item->{location}) is empty
      if ($item->{location} eq "") {
        if ($item->{ccode} ne $firstitem->{ccode}) {
          $item->{problem} = "Wrong collection";
        }
      }
      if ($item->{problem} eq "item not in system" || $item->{problem} eq "item not found") {
        $item->{problem} = "item not in Koha";
  		}

      additemtobarcodes($item,@barcodes);
    }

    # item sort - add error message if cn_sort isn't greater than previous item
		 unless ( $i == 0 ) {
            my $previous_item = $sortbarcodes[ $i - 1 ];
#            if ( $previous_item && $item->{cn_sort} lt $previous_item->{cn_sort} ) {
#                $item->{out_of_order} = 1;
#        				additemtobarcodes($item,@barcodes);
#            }
        }

          my $next_item = $sortbarcodes[ $i + 1 ];
          if ( $next_item && $item->{cn_sort} gt $next_item->{cn_sort} ) {
              $item->{out_of_order} = 1;
              additemtobarcodes($item,@barcodes);
          }

	}

	#end of checks
	# push ( $items, ( $item ) );
	# $cgi->cookie( 'barcodes' => \@barcodes );

	# my @test = $cgi;
	# $template->param( 'test' => \@oldBarcodes );

	$template->param( 'barcodes' => \@barcodes );
	$template->param( error => \@errorloop ) if (@errorloop);
  my $end = time();
  my $time = $end - $start;
  my $enda = time();
  my $timea = $end - $starta;

  $template->param('time' => $time);
    $template->param('timea' => $timea);

  $self->output_html( $template->output() );
}


sub additemtobarcodes {
    my ( $item, $barcodes ) = @_;
    my $itemno = $item->{itemnumber};
    # since the script appends to $item, we can just overwrite the hash entry
    $barcodes->{$itemno} = $item;
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
