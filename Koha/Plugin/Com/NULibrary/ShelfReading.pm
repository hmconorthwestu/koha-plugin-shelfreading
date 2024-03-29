package Koha::Plugin::Com::NULibrary::ShelfReading;

## It's good practice to use Modern::Perl
use Modern::Perl;
use strict;
no warnings 'experimental::smartmatch';

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use CGI qw ( -utf8 );
#use CGI::Session;
my $input = CGI->new;
my $bc = $input->param('bc');
my @oldBarcodes = $input->multi_param('oldBarcodes');
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
use Koha::Item;
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
# for Testing
use Data::Dumper;
use Library::CallNumber::LC;
use Koha::DateUtils qw(dt_from_string);

my $starta = time();
## Here we set our plugin version
our $VERSION = "1.1.0";

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

    my $dt = DateTime->now;
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
  my @error;
  my $erroritems = 0;
  my $timea;
  #$timea .= 'old Barcodes ' . Dumper(\@oldBarcodes);

	my $count = 0;
	foreach $b (@oldBarcodes) {
  #  $timea .= 'old Barcodes ' . Dumper(\@oldBarcodes);
    if ($b == $bc) {
        $duplicate = 1;
#        $timea .= 'duplicate';
    } else {
      $duplicate = 0;
#      $timea .= 'not duplicate';
    }
    	my $item = Koha::Items->find({barcode => $b});
  		if ( $item ) {
  #      $timea .= 'item found = ' . $b;
        $item = $item->unblessed;
        push @sortbarcodes, $item;
        push @barcodes, $item;
      } else {
  #      $timea .= 'item NOT found = ' . $b;
        $item->{itemcallnumber} = $b;
        $item->{itemnumber} = $b;
        $item->{barcode} = $b;
        $item->{problem} = "item not found";
        $erroritems++;
        push @barcodes, $item;
      }
      	$count = $count + 1;
#        $timea .= 'count ' . $count;
  }


  my $template = $self->get_template({ file => 'inventory2.tt' });

	#if ($cgi->cookie( 'barcodes' )) {
	#	@barcodes = $cgi->cookie( 'barcodes' );
	#	my $test = "cookie (barcodes) does exist";
	#	$template->param( 'test' => $test );
	#}
  unless ($duplicate == 1) {

  	# set date to log in datelastseen column
  	my $dt = DateTime->now;
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
      $erroritems++;
      if ( !@barcodes ) {
        # if this is the first item scanned, send restart Error
        @error = "restart - item not found";
      }
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
		} elsif ( $item->{withdrawn} ) {
			$item->{problem} = "item is marked as withdrawn";
      additemtobarcodes($item,@barcodes);
		} elsif ( $item->{lost} ) {
			$item->{problem} = "item is marked as lost";
      additemtobarcodes($item,@barcodes);
		} elsif ( $item->{itemcallnumber} eq "" || $item->{itemcallnumber} eq "undef" ) {
      $item->{problem} = "sort field missing - sort manually";
      additemtobarcodes($item,@barcodes);
    } elsif ( $item->{problem} && $item->{problem} eq "item not found" ) {
      additemtobarcodes($item,@barcodes);
    }
    if ( $i == 0 && $firstitem->{problem} ) {
      @error = "restart";
   }

    # compare to first item - check for wrong branch, wrong holding branch, wrong collection
    unless ( $i == 0 ) {
      if ( $item->{homebranch} ne $firstitem->{homebranch} ) {
        $item->{problem} = "Wrong branch library";
        additemtobarcodes($item,@barcodes);
      } elsif ($item->{holdingbranch} ne $firstitem->{holdingbranch}) {
        $item->{problem} = "Wrong branch library";
        additemtobarcodes($item,@barcodes);
      } elsif ( defined($item->{location}) ) {
        if ( defined($firstitem->{location}) ) {
          if ( $firstitem->{location} ne $item->{location} ) {
              # both items have locations but they don't match
            $item->{problem} = "Wrong shelving location";
            additemtobarcodes($item,@barcodes);
          }
        } else {
          # item has a location but firstitem doesn't
          $item->{problem} = "Wrong shelving location";
          additemtobarcodes($item,@barcodes);
        }
      } elsif ( !defined($item->{location}) ) {
        if ( defined($firstitem->{location}) ) {
            # firstitem has a shelving location but current item doesn't
            $item->{problem} = "Wrong shelving location";
            additemtobarcodes($item,@barcodes);
        } else {
          # neither item has a location. Compare ccodes
          if ( $item->{ccode} ne $firstitem->{ccode} ) {
            $item->{problem} = "Wrong collection";
            additemtobarcodes($item,@barcodes);
          }
        }
      }
      # problem - this will also remove first item
      if ( $item->{problem} ) {
        $erroritems++;
        # remove problem items from sorting
        splice(@sortbarcodes, $i, 1);
        $i--;
      }
    }
  }
# end of checks
my $count_out_of_order;
my @move;
if ( scalar(@sortbarcodes) > 0 ) {

   my @cnsort;
   my $cnsort;
   my @cnsorted;
  my $lastadded;

  while ( my ($key, $value) = each @sortbarcodes ) {
    # get all cnsort values into array, skip those with sequential duplicates

    # sort volumes before other items like index and supplement
    my $fullcallno;
    if ($value->{enumchron}) {
      my $enumchron = $value->{enumchron};
      if (substr($enumchron, 0, 2) eq "v.") {
        $enumchron = substr $enumchron, 2;
      }
      $fullcallno = $value->{itemcallnumber} . $enumchron;
    } else {
      $fullcallno = $value->{itemcallnumber};
    }

    unless ($lastadded && $fullcallno eq $lastadded ) {
      my $ncallnumber;
      if ( $value->{cn_source} eq "lcc" ) {
        my $callnumber = $fullcallno;
        $callnumber = Library::CallNumber::LC->new($callnumber);
        $ncallnumber = $callnumber->normalize;
      } else {
          $ncallnumber = $fullcallno;
      }
      push(@cnsort,$ncallnumber);
      $lastadded = $fullcallno;
    }
  }
     # build sorted array from cn_sort
     @cnsorted = sort(@cnsort);

 # begin shelf sort function that will not stop looping when copied into the shelf sort sub
  unless ( @cnsort ~~ @cnsorted && @cnsorted ~~ @cnsort ) {

  # hashes to hold data for calculations
	my %chunk = ();
	my %chunks = ();
	@move = ();
	my $chunk_key = 0;
	my $ct = scalar(@cnsort);
	my $c = 0;

	until ( @cnsort ~~ @cnsorted && @cnsorted ~~ @cnsort ) {
	  %chunk = ();
	  %chunks = ();
	  $chunk_key = 0;
	  $c++;
		if ($c > $ct) {
			last;
		  }

		  for my $item_key (0 .. $#cnsort) {
			# find the given item's position in the sorted array
			my $foundkey = first { $cnsorted[$_] eq $cnsort[$item_key] } 0..$#cnsorted;

			# calculate distance from where item is in sorted array
			my $d = $foundkey - $item_key;
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
			push @{$chunk{i}},$item_key;

			# record distance first key is from where it should be
			$chunk{d} = $d;

			# record key of first item in chunk
			$chunk{f} = $chunk{i}[0];

			# count how many items in chunk
			my @testd = exists( $chunk{i} ) ? @{ $chunk{i} } : ();
			$chunk{s} = scalar(@testd);

			# add the chunk to a hash of chunks
			$chunks{$chunk_key} = {%chunk};

		  }

		  # find the greatest distance number
		  my $chunk_dist = 0;
		  while ( my ($k, $v) = each %chunks ) {
			if ( abs($chunks{$k}{d}) > $chunk_dist) {
			  $chunk_dist = abs($chunks{$k}{d});
			}
		  }

		  # find the key of the chunk with the greatest distance number
		  my $chunk_move = 0;
		  while ( my ($k, $v) = each %chunks ) {
			if ( abs($chunks{$k}{d}) eq $chunk_dist) {
			  $chunk_move = $k;
			  for my $i ( @{$chunks{$k}{i}} ) {
				push @move, $cnsort[$i];
			  }
			  			last;
			}

		  }

		  # change the f value of the greatest distance chunk, to f + d (distance)
		  $chunks{$chunk_move}{f} = $chunks{$chunk_move}{f} + $chunks{$chunk_move}{d};

		  # adjust f values up or down so there are no duplicate f values and chunks land in correct order by f values
		  if ($chunks{$chunk_move}{d} > 0 ) {
			foreach my $k (sort keys %chunks ) {
			  if ( $k != $chunk_move && $chunks{$k}{f} <= $chunks{$chunk_move}{f}) {
				$chunks{$k}{f} = $chunks{$k}{f}-1;
			  }
			}
		  } elsif ($chunks{$chunk_move}{d} < 0 ) {
			foreach my $k (sort keys %chunks ) {
			  if ( $k != $chunk_move && $chunks{$k}{f} >= $chunks{$chunk_move}{f} ) {
				$chunks{$k}{f} = $chunks{$k}{f}+1;
			  }
			}
		  }

		  # copy call number array into a different array
		  my @prev = @cnsort;
		  # reset call number array
		  @cnsort = ();
		  # sort chunks by f value, into correct order
		  foreach my $sorted ( sort { $chunks{$a}{f} <=> $chunks{$b}{f} } keys %chunks ) {
  			my $test = $chunks{$sorted}{i};
  			for my $i ( values @{$chunks{$sorted}{i}} ) {
  		  # instead of create new cnsort array with keys as values in correct order, just add prev value into array
  			  push @cnsort, $prev[$i];
  			}
		  }
	  # this brackets ends until:
	  }
    # Make move array values unique, by building new array and skipping adding values we've already seen
    my %seenmove;
    @move = grep { ! $seenmove{ $_ }++ } @move;
  # this bracket ends outer unless
	}


  if ( @move ) {
    $count_out_of_order = scalar(@move);
    if ( @move eq "loop error" ) {
      @error = "until loop not stopping";
    } else {
      while ( my ($key, $value) = each @sortbarcodes ) {
        my $enumchron = $value->{enumchron};
        if (substr($enumchron, 0, 2) eq "v.") {
          $enumchron = substr $enumchron, 2;
        }
        my $fullcallno = $value->{itemcallnumber} . $enumchron;
        my $ncallnumber;
        if ( $value->{cn_source} eq "lcc" ) {
          my $callnumber = $fullcallno;
          $callnumber = Library::CallNumber::LC->new($callnumber);
          $ncallnumber = $callnumber->normalize;
        } else {
          $ncallnumber = $fullcallno;
        }
  		  if ( $ncallnumber ~~ @move ) {
    			$value->{out_of_order} = 1;
    			additemtobarcodes($value,@barcodes);
  		  }
		  }
    }
  }
# end handling if count of barcodes is > 0
}


	$template->param( 'barcodes' => \@barcodes );
	$template->param( errorloop => \@error ) if (@error);
  $template->param( 'misshelved' => $count_out_of_order ) if ($count_out_of_order);
  $template->param( 'erroritems' => $erroritems ) if ($erroritems);
  my $end = time();
#  my $time = $end - $start;
  my $enda = time();
#  my $timea = $end - $starta;


#  $template->param('time' => $time);
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

;
