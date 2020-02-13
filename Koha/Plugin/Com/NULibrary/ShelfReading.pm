package Koha::Plugin::Com::NULibrary::ShelfReading;

## It's good practice to use Modern::Perl
use Modern::Perl;

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

    unless ( $cgi->param('submitted') ) {
        $self->inventory1();
    }
    else {
        $self->inventory1();
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
sub inventory {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'inventory.tt' });
	
	# to get lists of collections and shelving locations to choose from
	my $location=$input->param('location') || '';
	my $collection=$input->param('collection') || '';
	# set date to log in datelastseen column
	my $datelastseen = '%Y-%m-%d';
	# gets branch that Koha is logged into
	my $branchcode = $input->param('branchcode') || '';
	# confirmation that form was submitted
	my $op         = $input->param('op');

    $self->output_html( $template->output() );
}
sub inventory1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'inventory1.tt' });
	
	# set date to log in datelastseen column
	my $datelastseen = '%Y-%m-%d';
	my $op         = $input->param('op');
	
$template->param(
    uploadedbarcodesflag     => $bc ? 1 : 0,
);

my $results = {};
my @scanned_items;
my @errorloop;
if ( $bc && length($bc) > 0 ) {
    my $dbh = C4::Context->dbh;
    my $date = $datelastseen;

    my $strsth  = "select * from issues, items where items.itemnumber=issues.itemnumber and items.barcode =?";
    my $qonloan = $dbh->prepare($strsth);
    $strsth="select * from items where items.barcode =? and items.withdrawn = 1";
    my $qwithdrawn = $dbh->prepare($strsth);

    my @barcodes;
    my @uploadedbarcodes;

    my $sth = $dbh->column_info(undef,undef,"items","barcode");
    my $barcode_def = $sth->fetchall_hashref('COLUMN_NAME');
    my $barcode_size = $barcode_def->{barcode}->{COLUMN_SIZE};
    my $err_length=0;
    my $err_data=0;
    my $lines_read=0;
    binmode($bc, ":encoding(UTF-8)");
    while (my $barcode=<$bc>) {
        my $split_chars = C4::Context->preference('BarcodeSeparators');
        push @uploadedbarcodes, grep { /\S/ } split( /[$split_chars]/, $barcode );
    }
    for my $barcode (@uploadedbarcodes) {
        next unless $barcode;
        ++$lines_read;
        if (length($barcode)>$barcode_size) {
            $err_length += 1;
        }
        my $check_barcode = $barcode;
        $check_barcode =~ s/\p{Print}//g;
        if (length($check_barcode)>0) { # Only printable unicode characters allowed.
            $err_data += 1;
        }
        next if length($barcode)>$barcode_size;
        next if ( length($check_barcode)>0 );
        push @barcodes,$barcode;
    }
    $template->param( LinesRead => $lines_read );
    if (! @barcodes) {
        push @errorloop, {'barcode'=>'No valid barcodes!'};
        $op=''; # force the initial inventory screen again.
    }
    else {
        $template->param( err_length => $err_length,
                          err_data   => $err_data );
    }
    foreach my $barcode (@barcodes) {
        if ( $qwithdrawn->execute($barcode) && $qwithdrawn->rows ) {
            push @errorloop, { 'barcode' => $barcode, 'ERR_WTHDRAWN' => 1 };
        } else {
            my $item = Koha::Items->find({barcode => $barcode});
            if ( $item ) {
                $item = $item->unblessed;
                # Modify date last seen for scanned items, remove lost status
                ModItem( { itemlost => 0, datelastseen => $date }, undef, $item->{'itemnumber'} );
                $moddatecount++;
                # update item hash accordingly
                $item->{itemlost} = 0;
                $item->{datelastseen} = $date;
                push @scanned_items, $item;
            } else {
                push @errorloop, { barcode => $barcode, ERR_BARCODE => 1 };
            }
        }
    }
    $template->param( date => $date );
    $template->param( errorloop => \@errorloop ) if (@errorloop);
}

    $self->output_html( $template->output() );
}

sub inventory2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
	
	# set all parameters needed	
my $minlocation=$input->param('minlocation') || '';
my $maxlocation=$input->param('maxlocation');
my $class_source=$input->param('class_source');
$maxlocation=$minlocation.'Z' unless ( $maxlocation || ! $minlocation );
my $location=$input->param('location') || '';
my $ignoreissued=$input->param('ignoreissued');
my $ignore_waiting_holds = $input->param('ignore_waiting_holds');
my $datelastseen = $input->param('datelastseen'); # last inventory date
my $branchcode = $input->param('branchcode') || '';
my $branch     = $input->param('branch');
my $op         = $input->param('op');
my $compareinv2barcd = $input->param('compareinv2barcd');
my $dont_checkin = $input->param('dont_checkin');
my $out_of_order = $input->param('out_of_order');


# tell which template to load and pass needed params
#my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
#    {   template_name   => $self->mbf_path( $args->{'ShelfReading/inventory.tt'} ),
##        query           => $input,
#        type            => "intranet",
 #       authnotrequired => 0,
#        flagsrequired   => { tools => 'inventory' },
#        debug           => 1,
#    }
#);
my $template = $self->get_template({ file => 'inventory.tt' });

my @location_list;
my @collection_list;
my $authorisedvalue_categories = '';

my $frameworks = Koha::BiblioFrameworks->search({}, { order_by => ['frameworktext'] })->unblessed;
unshift @$frameworks, { frameworkcode => '' };

# build list of possible locations
for my $fwk ( @$frameworks ){
  my $fwkcode = $fwk->{frameworkcode};
  my $mss = Koha::MarcSubfieldStructures->search({ frameworkcode => $fwkcode, kohafield => 'items.location', authorised_value => [ -and => {'!=' => undef }, {'!=' => ''}] });
  my $authcode = $mss->count ? $mss->next->authorised_value : undef;
    if ($authcode && $authorisedvalue_categories!~/\b$authcode\W/){
      $authorisedvalue_categories.="$authcode ";
      my $data=GetAuthorisedValues($authcode);
      foreach my $value (@$data){
        $value->{selected}=1 if ($value->{authorised_value} eq ($location));
      }
      push @location_list,@$data;
    }
}

# build list of possible collections
for my $fwk ( @$frameworks ){
  my $fwkcode = $fwk->{frameworkcode};
  my $mss = Koha::MarcSubfieldStructures->search({ frameworkcode => $fwkcode, kohafield => 'items.ccode', authorised_value => [ -and => {'!=' => undef }, {'!=' => ''}] });
  my $authcode = $mss->count ? $mss->next->authorised_value : undef;
    if ($authcode && $authorisedvalue_categories!~/\b$authcode\W/){
      $authorisedvalue_categories.="$authcode ";
      my $data=GetAuthorisedValues($authcode);
      foreach my $value (@$data){
        $value->{selected}=1 if ($value->{authorised_value} eq ($location));
      }
      push @collection_list,@$data;
    }
}


my $statuses = [];
my @notforloans;
for my $statfield (qw/items.notforloan items.itemlost items.withdrawn items.damaged/){
    my $hash = {};
    $hash->{fieldname} = $statfield;
    my $mss = Koha::MarcSubfieldStructures->search({ frameworkcode => '', kohafield => $statfield, authorised_value => [ -and => {'!=' => undef }, {'!=' => ''}] });
    $hash->{authcode} = $mss->count ? $mss->next->authorised_value : undef;
    if ($hash->{authcode}){
        my $arr = GetAuthorisedValues($hash->{authcode});
        if ( $statfield eq 'items.notforloan') {
            # Add notforloan == 0 to the list of possible notforloan statuses
            # The lib value is replaced in the template
            push @$arr, { authorised_value => 0, id => 'stat0' , lib => '__IGNORE__' } if ! grep { $_->{authorised_value} eq '0' } @$arr;
            @notforloans = map { $_->{'authorised_value'} } @$arr;
        }
        $hash->{values} = $arr;
        push @$statuses, $hash;
    }
}

$template->param( statuses => $statuses );
my $staton = {}; #authorized values that are ticked
for my $authvfield (@$statuses) {
    $staton->{$authvfield->{fieldname}} = [];
    for my $authval (@{$authvfield->{values}}){
        if ( defined $input->param('status-' . $authvfield->{fieldname} . '-' . $authval->{authorised_value}) && $input->param('status-' . $authvfield->{fieldname} . '-' . $authval->{authorised_value}) eq 'on' ){
            push @{$staton->{$authvfield->{fieldname}}}, $authval->{authorised_value};
        }
    }
}

my @class_sources = Koha::ClassSources->search({ used => 1 });
my $pref_class = C4::Context->preference("DefaultClassificationSource");


$template->param(
    locations 		       => \@location_list,
	collections	    	    => \@collection_list,
    today                    => dt_from_string,
    minlocation              => $minlocation,
    maxlocation              => $maxlocation,
    location                 => $location,
    ignoreissued             => $ignoreissued,
    branchcode               => $branchcode,
    branch                   => $branch,
    datelastseen             => $datelastseen,
    compareinv2barcd         => $compareinv2barcd,
    uploadedbarcodesflag     => $uploadbarcodes ? 1 : 0,
    ignore_waiting_holds     => $ignore_waiting_holds,
    class_sources            => \@class_sources,
    pref_class               => $pref_class
);

my $results = {};
my @scanned_items;
my @errorloop;
my $moddatecount = 0;
if ( $uploadbarcodes && length($uploadbarcodes) > 0 ) {
    my $dbh = C4::Context->dbh;
    my $date = dt_from_string( scalar $input->param('setdate') );
    $date = output_pref ( { dt => $date, dateformat => 'iso' } );

    my $strsth  = "select * from issues, items where items.itemnumber=issues.itemnumber and items.barcode =?";
    my $qonloan = $dbh->prepare($strsth);
    $strsth="select * from items where items.barcode =? and items.withdrawn = 1";
    my $qwithdrawn = $dbh->prepare($strsth);

    my @barcodes;
    my @uploadedbarcodes;

    my $sth = $dbh->column_info(undef,undef,"items","barcode");
    my $barcode_def = $sth->fetchall_hashref('COLUMN_NAME');
    my $barcode_size = $barcode_def->{barcode}->{COLUMN_SIZE};
    my $err_length=0;
    my $err_data=0;
    my $lines_read=0;
    binmode($uploadbarcodes, ":encoding(UTF-8)");
    while (my $barcode=<$uploadbarcodes>) {
        my $split_chars = C4::Context->preference('BarcodeSeparators');
        push @uploadedbarcodes, grep { /\S/ } split( /[$split_chars]/, $barcode );
    }
    for my $barcode (@uploadedbarcodes) {
        next unless $barcode;
        ++$lines_read;
        if (length($barcode)>$barcode_size) {
            $err_length += 1;
        }
        my $check_barcode = $barcode;
        $check_barcode =~ s/\p{Print}//g;
        if (length($check_barcode)>0) { # Only printable unicode characters allowed.
            $err_data += 1;
        }
        next if length($barcode)>$barcode_size;
        next if ( length($check_barcode)>0 );
        push @barcodes,$barcode;
    }
    $template->param( LinesRead => $lines_read );
    if (! @barcodes) {
        push @errorloop, {'barcode'=>'No valid barcodes!'};
        $op=''; # force the initial inventory screen again.
    }
    else {
        $template->param( err_length => $err_length,
                          err_data   => $err_data );
    }
    foreach my $barcode (@barcodes) {
        if ( $qwithdrawn->execute($barcode) && $qwithdrawn->rows ) {
            push @errorloop, { 'barcode' => $barcode, 'ERR_WTHDRAWN' => 1 };
        } else {
            my $item = Koha::Items->find({barcode => $barcode});
            if ( $item ) {
                $item = $item->unblessed;
                # Modify date last seen for scanned items, remove lost status
                ModItem( { itemlost => 0, datelastseen => $date }, undef, $item->{'itemnumber'} );
                $moddatecount++;
                # update item hash accordingly
                $item->{itemlost} = 0;
                $item->{datelastseen} = $date;
                unless ( $dont_checkin ) {
                    $qonloan->execute($barcode);
                    if ($qonloan->rows){
                        my $data = $qonloan->fetchrow_hashref;
                        my ($doreturn, $messages, $iteminformation, $borrower) =AddReturn($barcode, $data->{homebranch});
                        if( $doreturn ) {
                            $item->{onloan} = undef;
                            $item->{datelastseen} = dt_from_string;
                        } else {
                            push @errorloop, { barcode => $barcode, ERR_ONLOAN_NOT_RET => 1 };
                        }
                    }
                }
                push @scanned_items, $item;
            } else {
                push @errorloop, { barcode => $barcode, ERR_BARCODE => 1 };
            }
        }
    }
    $template->param( date => $date );
    $template->param( errorloop => \@errorloop ) if (@errorloop);
}

# Build inventorylist: used as result list when you do not pass barcodes
# This list is also used when you want to compare with barcodes
my ( $inventorylist, $rightplacelist );
if ( $op && ( !$uploadbarcodes || $compareinv2barcd )) {
    ( $inventorylist ) = GetItemsForInventory({
      minlocation  => $minlocation,
      maxlocation  => $maxlocation,
      class_source => $class_source,
      location     => $location,
      ignoreissued => $ignoreissued,
      datelastseen => $datelastseen,
      branchcode   => $branchcode,
      branch       => $branch,
      offset       => 0,
      statushash   => $staton,
      ignore_waiting_holds => $ignore_waiting_holds,
    });
}
# Build rightplacelist used to check if a scanned item is in the right place.
if( @scanned_items ) {
    ( $rightplacelist ) = GetItemsForInventory({
      minlocation  => $minlocation,
      maxlocation  => $maxlocation,
      class_source => $class_source,
      location     => $location,
      ignoreissued => undef,
      datelastseen => undef,
      branchcode   => $branchcode,
      branch       => $branch,
      offset       => 0,
      statushash   => undef,
      ignore_waiting_holds => $ignore_waiting_holds,
    });
    # Convert the structure to a hash on barcode
    $rightplacelist = {
        map { $_->{barcode} ? ( $_->{barcode}, $_ ) : (); } @$rightplacelist
    };
}

# Report scanned items that are on the wrong place, or have a wrong notforloan
# status, or are still checked out.
for ( my $i = 0; $i < @scanned_items; $i++ ) {

    my $item = $scanned_items[$i];

    $item->{notforloancode} = $item->{notforloan}; # save for later use
    my $fc = $item->{'frameworkcode'} || '';

    # Populating with authorised values description
    foreach my $field (qw/ location notforloan itemlost damaged withdrawn /) {
        my $av = Koha::AuthorisedValues->get_description_by_koha_field(
            { frameworkcode => $fc, kohafield => "items.$field", authorised_value => $item->{$field} } );
        if ( $av and defined $item->{$field} and defined $av->{lib} ) {
            $item->{$field} = $av->{lib};
        }
    }

    # If we have scanned items with a non-matching notforloan value
    if( none { $item->{'notforloancode'} eq $_ } @notforloans ) {
        $item->{problems}->{changestatus} = 1;
        additemtoresults( $item, $results );
    }

    # Check for items shelved out of order
    if ($out_of_order) {
        unless ( $i == 0 ) {
            my $previous_item = $scanned_items[ $i - 1 ];
            if ( $previous_item && $item->{cn_sort} lt $previous_item->{cn_sort} ) {
                $item->{problems}->{out_of_order} = 1;
                additemtoresults( $item, $results );
            }
        }
        unless ( $i == scalar(@scanned_items) ) {
            my $next_item = $scanned_items[ $i + 1 ];
            if ( $next_item && $item->{cn_sort} gt $next_item->{cn_sort} ) {
                $item->{problems}->{out_of_order} = 1;
                additemtoresults( $item, $results );
            }
        }
    }

    # Report an item that is checked out (unusual!) or wrongly placed
    if( $item->{onloan} ) {
        $item->{problems}->{checkedout} = 1;
        additemtoresults( $item, $results );
        next; # do not modify item
    } elsif( !exists $rightplacelist->{ $item->{barcode} } ) {
        $item->{problems}->{wrongplace} = 1;
        additemtoresults( $item, $results );
    }
}

# Compare barcodes with inventory list, report no_barcode and not_scanned.
# not_scanned can be interpreted as missing
if ( $compareinv2barcd ) {
    my @scanned_barcodes = map {$_->{barcode}} @scanned_items;
    for my $item ( @$inventorylist ) {
        my $barcode = $item->{barcode};
        if( !$barcode ) {
            $item->{problems}->{no_barcode} = 1;
        } elsif ( grep { $_ eq $barcode } @scanned_barcodes ) {
            next;
        } else {
            $item->{problems}->{not_scanned} = 1;
        }
        additemtoresults( $item, $results );
    }
}

# Construct final results, add biblio information
my $loop = $uploadbarcodes
    ? [ map { $results->{$_} } keys %$results ]
    : $inventorylist // [];
for my $item ( @$loop ) {
    my $biblio = Koha::Biblios->find( $item->{biblionumber} );
    $item->{title} = $biblio->title;
    $item->{author} = $biblio->author;
}

$template->param(
    moddatecount => $moddatecount,
    loop         => $loop,
    op           => $op,
);

    $self->output_html($template->output() );
}

sub tool_step2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'inventory.tt' });

    my $borrowernumber = C4::Context->userenv->{'number'};
    my $borrower = Koha::Patrons->find( $borrowernumber );
    $template->param( 'victim' => $borrower->unblessed() );
    $template->param( 'victim' => $borrower );

    $borrower->firstname('Bob')->store;

    my $dbh = C4::Context->dbh;

    my $table = $self->get_qualified_table_name('mytable');

    my $sth   = $dbh->prepare("SELECT DISTINCT(borrowernumber) FROM $table");
    $sth->execute();
    my @victims;
    while ( my $r = $sth->fetchrow_hashref() ) {
        my $brw = Koha::Patrons->find( $r->{'borrowernumber'} )->unblessed();
        push( @victims, ( $brw ) );
    }
   

    $dbh->do( "INSERT INTO $table ( borrowernumber ) VALUES ( ? )",
        undef, ($borrowernumber) );

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
