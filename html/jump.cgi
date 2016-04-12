#!/usr/bin/perl -wT

########
# jump.cgi
# -------------
#
# Ylink site
#
# Created by: Steve DiDomenico  steve@northwestern.edu
#       Date: 2007-08-24
#   Modified: 2011-02-24
#
# This redirects to a site given a short query that has been saved to the database.
#
########

use strict;
use POSIX;
use CGI qw/:all/;
use CGI::Carp qw(fatalsToBrowser);
use lib "/usr/home/sedidome/factslap/modules";
use Ylink qw/:all/;

sub main
{
	connectToDB(0);
	my ($iret,$error,$shortname) = checkParams(param('s'));

	if ($iret) {
		printPage('Problem', $error);
	}
	else {
		my (@links) = getURL($shortname);
	
		if (!($links[0]->{'url'})) {
			printPage('Problem', div({-id=>'content'}, 'Your link could not be found. Make sure your ' .
		  	                   'link is correct and try again.'));
		}
		elsif ($links[0]->{'url'} eq '') {
			printPage('Problem', 'This link appears to no longer be available.');
		}
		else {
			printRedirect($links[0]->{'url'});
		}
	}
	
	$dbh->disconnect() if $dbh;
	exit(0);
}

###
# checkParams
# -----------
# Checks to make sure the shortname parameter is defined
# Requires: shortname
# Returns : (0,'',shortname) on success
#           (1,error message, undef) on error
###
sub checkParams
{
	my ($shortname) = @_;
	my $iret = 0;
	my $error = '';
	
	if (!defined($shortname)) {
		$iret = 1;
		$error = 'There was a problem with your link. Make sure your ' .
		         'link is correct and try again';
	}

	return($iret,$error,$shortname);
}

main();

#
