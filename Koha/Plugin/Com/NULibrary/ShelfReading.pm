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
# to get item details:
use Koha::Items;
#use List::MoreUtils qw( none );
use List::Util qw(first);

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
# to compare sorted and unsorted lists:
use Array::Utils qw(:all);

my $starta = time();
## Here we set our plugin version
our $VERSION = "v1.0.201";

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
  my @sortbarcodes;
  my $duplicate;
  my @errorloop;

	my $count = 0;
	foreach $b (@oldBarcodes) {
    if ($b == $bc) {
      $duplicate = 1;
    }
  		my $item = Koha::Items->find({barcode => $b});
  		if ( $item ) {
        $item = $item->unblessed;
        push @sortbarcodes, $item;
        push @barcodes, $item;
      } else {
        $item->{itemcallnumber} = $b;
        $item->{itemnumber} = $b;
        $item->{barcode} = $b;
        $item->{problem} = "item not found";
        push @barcodes, $item;
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
        # Modify date last seen for scanned items, remove lost status
        $kohaitem->set({ itemlost => 0, datelastseen => $datelastseen })->store;
        # update item hash accordingly
        $item->{itemlost} = 0;
        $item->{datelastseen} = $datelastseen;
        push @sortbarcodes, $item;
        push @barcodes, $item;
  	} else {
      $item->{itemcallnumber} = $bc;
      $item->{itemnumber} = $bc;
      $item->{barcode} = $bc;
      $item->{problem} = "item not found";
      push @barcodes, $item;
    }
  }

# check item branches, location, collection, checked out, lost, missing sort call number

# start of checks - need to add mending and/or processing
	for ( my $i = 0; $i < @sortbarcodes; $i++ ) {
		my $item = $sortbarcodes[$i];
    my $firstitem = $sortbarcodes[0];

    if ( $item->{onloan} ) {
			$item->{problem} = "item is checked out";
      additemtobarcodes($item,@barcodes);
      # remove item from sorting
      splice(@sortbarcodes, $i, 1);
		} elsif ( $item->{withdrawn} ) {
			$item->{problem} = "item is marked as withdrawn";
      additemtobarcodes($item,@barcodes);
      # remove item from sorting
      splice(@sortbarcodes, $i, 1);
		} elsif ( $item->{lost} ) {
			$item->{problem} = "item is marked as lost";
      additemtobarcodes($item,@barcodes);
      # remove item from sorting
      splice(@sortbarcodes, $i, 1);
		} elsif ( $item->{cn_sort} eq "" || $item->{cn_sort} eq "undef" ) {
      $item->{problem} = "item missing sorting call number";
      additemtobarcodes($item,@barcodes);
      # remove item from sorting
      splice(@sortbarcodes, $i, 1);
    } elsif ( $item->{problem} eq "item not found" ) {
      additemtobarcodes($item,@barcodes);
      # remove item from sorting
      splice(@sortbarcodes, $i, 1);
    }

    # compare to first item - check for wrong branch, wrong holding branch, wrong collection
    unless ( $i == 0 ) {
#      my $firstitem = $sortbarcodes[0];
      if ( $item->{homebranch} ne $firstitem->{homebranch} ) {
        $item->{problem} = "Wrong branch library";
        additemtobarcodes($item,@barcodes);
        # remove item from sorting
        splice(@sortbarcodes, $i, 1);
      } elsif ($item->{holdingbranch} ne $firstitem->{holdingbranch}) {
        $item->{problem} = "Wrong branch library";
        additemtobarcodes($item,@barcodes);
        # remove item from sorting
        splice(@sortbarcodes, $i, 1);
      } elsif ( defined($item->{location}) ) {
        if ( defined($firstitem->{location}) ) {
          if ( $firstitem->{location} ne $item->{location} ) {
              # both items have locations but they don't match
            $item->{problem} = "Wrong shelving location";
            additemtobarcodes($item,@barcodes);
            # remove item from sorting
            splice(@sortbarcodes, $i, 1);
          }
        } else {
          # item has a location but firstitem doesn't
          $item->{problem} = "Wrong shelving location";
          additemtobarcodes($item,@barcodes);
          # remove item from sorting
          splice(@sortbarcodes, $i, 1);
        }
      } elsif ( !defined($item->{location}) ) {
        if ( defined($firstitem->{location}) ) {
            # firstitem has a shelving location but current item doesn't
            $item->{problem} = "Wrong shelving location";
            additemtobarcodes($item,@barcodes);
            # remove item from sorting
            splice(@sortbarcodes, $i, 1);
        } else {
          # neither item has a location. Compare ccodes
          if ( $item->{ccode} ne $firstitem->{ccode} ) {
            $item->{problem} = "Wrong collection";
            additemtobarcodes($item,@barcodes);
            # remove item from sorting
            splice(@sortbarcodes, $i, 1);
          }
        }
      }
    }
  }
# end of checks

my $timea;
 # sorting formula from https://www.perlmonks.org/?node_id=560304
my @sortedbarcodes = map  { $_->[0] }
             sort { $a->[1] cmp $b->[1] }
             map  { [ $_, $_->{cn_sort} ] }
             @sortbarcodes;

 my @cnsort;
 my @cnsorted;

 # create arrays of unsorted and sorted call numbers
 while ( my ($key, $value) = each @sortedbarcodes ) {
   push(@cnsorted,$value->{cn_sort});
 }
 while ( my ($key, $value) = each @sortbarcodes ) {
   push(@cnsort,$value->{cn_sort});
 }

my @move;
unless ( @cnsort ~~ @cnsorted && @cnsorted ~~ @cnsort ) {
  @move = shelf_sort(@cnsort, @cnsorted);
}

if ( @move ) {
  for ( my $i = 0; $i < @sortbarcodes; $i++ ) {
    my $item = $sortbarcodes[$i];
    foreach my $to_move ( @move ) {
      if ( $item->{cn_sort} eq $to_move ) {
        $item->{out_of_order} = 1;
        additemtobarcodes($item,@barcodes);
      }
    }
  }
}

	$template->param( 'barcodes' => \@barcodes );
	$template->param( error => \@errorloop ) if (@errorloop);
  my $end = time();
  my $time = $end - $start;
  my $enda = time();
#  my $timea = $end - $starta;

  $template->param('time' => $time);
  $template->param('timea' => $timea);

  $self->output_html( $template->output() );
}

sub shelf_sort {
  my (@cnsort, @cnsorted) = @_;

# hashes to hold data for calculations
  my %chunk;
  my %chunks;
  my @move;
  my $chunk_key = 0;

  until ( @cnsort ~~ @cnsorted && @cnsorted ~~ @cnsort ) {
    while (my ($k, $v) = each @cnsort) {
      # find the given item's position in the sorted array
      my $foundkey = first { $cnsorted[$_] eq $v } 0..$#cnsorted;
      # calculate distance from where item is in sorted array
      my $d = $foundkey - $k;
      if ( defined $chunks{$chunk_key} ) {
        if ( defined $chunk{d} ) {
          unless ( $chunk{d} eq $d ) {
            # if an item is a different distance from correct than the previous item, start a new chunk
            $chunk_key++;
            %chunk = ();
          }
        }
      }
      # save keys for all items in this chunk
      push @{$chunk{'i'}},$k;
      # record distance first key is from where it should be
      $chunk{d} = $d;
      # record key of first item in chunk
      $chunk{f} = $chunk{i}[0];
      # count how many items in chunk
      my @testd = exists( $chunk{'i'} ) ? @{ $chunk{'i'} } : ();
      $chunk{s} = scalar(@testd);
      # add the chunk to a hash of chunks
      $chunks{$chunk_key} = {%chunk};
    }

    # find the greatest distance number
    my $chunk_dist = 0;
    while ( my ($k, $v) = each %chunks ) {
      if ( $chunks{$k}{d} > $chunk_dist) {
        $chunk_dist = $chunks{$k}{d};
      }
    }

    # find the key of the chunk with the greatest distance number
    my $chunk_move = 0;
    while ( my ($k, $v) = each %chunks ) {
      if ( $chunks{$k}{d} eq $chunk_dist) {
        $chunk_move = $k;
        for my $i ( @{$chunks{$k}{i}} ) {
          push @move, @cnsort[$i];
        }
      }
    }

    # change the f value of the greatest distance chunk, to f + d (distance)
    $chunks{$chunk_move}{f} = $chunks{$chunk_move}{f} + $chunks{$chunk_move}{d};

    # adjust f values up or down so there are no duplicate f values and chunks land in correct order by f values
    if ($chunks{$chunk_move}{d} > 0 ) {
      while ( my ($k, $v) = each %chunks ) {
        if ( $k != $chunk_move && @$v{f} <= $chunks{$chunk_move}{f}) {
          $chunks{$k}{f} = $chunks{$k}{f}-1;
        }
      }
    } elsif ($chunks{$chunk_move}{d} < 0 ) {
      while ( my ($k, $v) = each %chunks ) {
        if ( $k != $chunk_move && @$v{f} <= $chunks{$chunk_move}{f} ) {
          $chunks{$k}{f} = $chunks{$k}{f}+1;
        }
      }
    }

    my @prev = @cnsort;
    @cnsort = ();
    # sort chunks by f value, into correct order
    foreach my $sorted ( sort { $chunks{$a}{f} <=> $chunks{$b}{f} } keys %chunks ) {
      for my $i ( @{$chunks{$sorted}{i}} ) {
        # create new cnsort array with keys as values in correct order
        push @cnsort, $i;
      }
    }
    while (my ($k, $v) = each @cnsort) {
      # substitute correct call number values in for key values
      @cnsort[$k] = @prev[$v];
    }
  }
  # return call numbers of items to move
  return @move;
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
