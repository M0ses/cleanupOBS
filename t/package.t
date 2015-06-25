#!/usr/bin/perl

use Test::More tests => 1;
use strict;
use warnings;
use feature 'say';


BEGIN { use_ok( 'OBS::Package::RevisionList' ); }

my $rev_list = OBS::Package::RevisionList->new(
		project=>'home:M0ses',
		package=>'TestPackage',
		path_to_obs=>'/srv/obs'
	  );

$rev_list->read_from_file();


$rev_list->map_revisions(sub{
	$_->locate_files();
});

$rev_list->map_revisions(sub{
	if ($_->verify_files()) {
		say sprintf("Revision %s OK",$_->id);
	} else {
		say sprintf("Revision %s NOT OK",$_->id);
	}
});

$rev_list->cleanup_revisions();

print $rev_list->to_string();

exit 0;
