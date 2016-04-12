#!/usr/bin/perl  -wT

########
# index.cgi
# -------------
#
# Ylink site
#
# Created by: Steve DiDomenico  steve@northwestern.edu
#       Date: 2007-08-24
#   Modified: 2011-02-24
#
########

use strict;
use POSIX;
use CGI qw/:all/;
use CGI::Carp qw(fatalsToBrowser);
use lib "/usr/home/sedidome/factslap/modules";
use Ylink qw/:all/;

#my $REMOTE_USER = remote_user();
my $REMOTE_USER = 'stevetest';

#$ENV{'REMOTE_ADDR'}
my $REMOTE_ADDR = remote_addr();

# Autoflush on
$| = 1;

main();

sub main
{
	if (defined(param('url'))) {
		sleep 1; # try to slow down folks who abuse the system
		connectToDB(1);
		my ($iret,$mess,$url,$shortname,$db_expires_time,$hr_expires_time,$created_by,$ip_address) = processURL();
		
		if ($iret == 0) {
			my $shorturl = 'http://' . $HOSTNAME . '/' . $shortname;
			printPage('Fact Slap: Success', 
			                     div({id=>'content'}, p({-id=>'saved'}, 'Your URL was saved as : ') .
			                     p({-id=>'shorturl'}, $shorturl . ' ' . br .
			                     a({-href=>$shorturl, -class=>'newwindow', -target=>'_blank'}, 'open in new window')) .
			                     p({-id=>'orginalurl'}, 'which when clicked will send folks ' .
			                                            'to your original URL: ' . br .
			                     a({-href=>$url, -target=>'_blank'}, scrunch($url)))));
		}
		else {
			displayMainPage('Your URL wasn\'t saved because ' . $mess);
		}
	}
	else {
		displayMainPage();
	}
	
	disconnectFromDB();
	exit(0);
}

##
# displayMainPage
# ---------------
# This displays the main page where users will enter their info. It will also be used to
# display an error message if there was a problem, and allow the user to correct their
# info.
# Requires: undef or an error message
##
sub displayMainPage
{
	my ($errormess) = @_;
	my $formattederror = '';
	my $title = 'Fact Slap';
	
	if (defined($errormess)) {
		$formattederror = p({-class=>'problem'}, $errormess);
		$title .= ': Problem';
	}
	
		printPage($title,
		          div({id=>'content'}, p({-id=>'title'}, 'Slap a fact. Create a shorter URL.') .
		          div({id=>'form'},
		          start_form(-name=>'ylink', -id=>'ylinkform', -action=>'index.cgi', -method=>'POST') .
		         			 $formattederror .
		               p('Enter URL: ' .
		              	 textfield(-type=>'text', -id=>'url', -name=>'url', -size=>'30')) .
		               p(checkbox(-name=>'is_generated',
		                             -id=>'is_generated',
                                -value=>'1',
                                -label=>'Choose my own link name',
                                -checked=>'')) .
		                p({-id=>'sn'}, 'Enter link name: ' . textfield(-type=>'text', -id=>'shortname', -name=>'shortname')) .
		                p({-id=>'submitbutton'}, submit(-name=>'submit', -value=>'Do it')) .
		                end_form)));
}


##
# processURL
# ----------
# This checks to make sure the url parameter is valid, and also tries to save the URL to the database.
##
sub processURL
{
	my $paramshortname = (defined(param('shortname')) ? param('shortname') : '');
	my $paramisgenerated = (defined(param('is_generated')) ? '1' : '0');

	my ($iret,$mess,$url,$is_generated,$shortname,$db_expires_time,$hr_expires_time,$created_by,$ip_address) = checkAndSetParams(param('url'),$paramisgenerated,$paramshortname,$REMOTE_USER,'3',$REMOTE_ADDR);
	
	if ($iret == 0 ) {
		if ($is_generated) { # save by shortname
			my $shortexists = undef;
			my @rows = undef;
			($shortexists,@rows) = getURL($shortname);
			
			if (defined($shortexists)) {
				$iret = 1;
				$mess = "the short name '$shortname' already exists. Please choose another.";
			}
			else {
				($iret,$mess) = saveNameURL($shortname,$url,$hr_expires_time,$created_by,$ip_address);
			}
		}
		else { # save by number
			($iret,$mess,$shortname) = saveNumberNameURL($url,$hr_expires_time,$created_by,$ip_address);
		}

		if ($iret != 0) { # the database update failed
			$mess .= ''; # try to return a user-friendly message
		}
		
	}
	return ($iret, $mess, $url, $shortname, $db_expires_time, $hr_expires_time, $created_by, $ip_address);
}

