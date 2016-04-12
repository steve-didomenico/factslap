package Ylink;
require 5.005;

##
# Ylink.pm
# -------------
# Created: 2007-08-24
# Modified: 2011-02-22
# Created by: Steve DiDomenico
#             steve@northwestern.edu
#
# Purpose: This is a shared library for the ylink program. This is used for creating a short
#          URL that can be used to forward to a longer URL. The short link can either by system
#          assigned via a number, or it can be a custom name that the user has chosen.
##

##
# Pragma and Library Declarations
##
use DBI;
use CGI qw/:standard/;
use POSIX qw/strftime/;
use Math::BaseCnv qw(:all);
use Regexp::Common qw /URI/;

##
# Global Variables
##
#$MYSQL_USERNAME_R   = "removed";
#$MYSQL_USERNAME_RW  = "removed";
#$MYSQL_PASSWORD_R   = "removed";
#$MYSQL_PASSWORD_RW  = "removed";
#$MYSQL_HOST         = "DBI:mysql:ylink:localhost";

$MYSQL_USERNAME_R   = "removed";
$MYSQL_USERNAME_RW  = "removed";
$MYSQL_PASSWORD_R   = "removed";
$MYSQL_PASSWORD_RW  = "removed";
$MYSQL_HOST         = "DBI:mysql:removed:removed.pair.com";


$HOSTNAME = "didomenico.us/factslap";

$dbh                = undef;

$MAX_RANDOM_NUMBER = 30; # used to determine how wide of a range of link ids are chosen

@basedigits = ['0'..'9', 'a'..'z', 'A'..'Z'];

@expires_values = ['1','2','4','7','14','28'];
%expires_labels = ('1' => '1 day',
                   '2' => '2 days',
                   '4' => '4 days',
                   '7' => '1 week',
                   '14' => '2 weeks',
                   '28' => '4 weeks');

@EXPORT_OK          = qw($dbh
       $MAX_RANDOM_NUMBER
       $HOSTNAME
       @expires_values
       %expires_labels
			 &connectToDB
			 &disconnectFromDB
			 &printPage
			 &printRedirect
			 &getURL
			 &getShortname
			 &updateURL
			 &replaceOldURL
			 &saveNumberNameURL
			 &saveNameURL
			 &saveURLRandom
			 &convertDecToBase
			 &convertBaseToDec
			 &checkAndSetParams
			 &setExpiresTime
			 &scrunch
			 );
%EXPORT_TAGS        = (
		       'all' => [@EXPORT_OK]
		       );
@ISA                = qw(Exporter);

##
# connectToDB
# -----------
# This subroutine is used to connect to the proper database.
# It can accept a parameter:
#     0 = connect with read permissions only
#     1 = connect with read/write permissions 
##
sub connectToDB
{
    my ($permissions) = @_;
    my ($mysqlusername, $mysqlpassword, $mysqlhost, $username_r, $password_r,
        $username_rw, $password_rw);
        
		$mysqlhost = $MYSQL_HOST;
		if ($permissions == 1) {
			$mysqlusername = $MYSQL_USERNAME_RW;
			$mysqlpassword = $MYSQL_PASSWORD_RW;
		}
		else {
			$mysqlusername = $MYSQL_USERNAME_R;
			$mysqlpassword = $MYSQL_PASSWORD_R;
		}
    eval {
        $dbh = DBI->connect($mysqlhost, $mysqlusername, $mysqlpassword,
                            {'RaiseError'  => 1, 
			     'PrintError'  => 1,
			     'LongReadLen' => 2**20-2,
			     'LongTruncOk' => 1,
                             'AutoCommit'  => 1});
    };
    if ($@) {
	    printPage('Database Down', 
	               'The database is currently down. Please try again later.' . $@);
    }
}


##
# disconnectFromDB
# ----------------
# This disconnects from the database cleanly
##
sub disconnectFromDB
{
	$dbh->disconnect() if $dbh;
}


##
# printPage
# ---------
# This subroutine is the main subroutine used to print out HTML pages. All
# printed information should be sent through this subroutine. 
##
sub printPage
{
	my ($title, $text) = @_;
	
	my $jqurl = '/factslap/j-s/jquery-1.5.1.min.js';
	my $jqvurl = '/factslap/j-s/jquery.validate.min.js';
	my $jlinkurl = '/factslap/j-s/linkvalidate.js';
	
		print header('-expires' => 'Mon, 26 Jul 1997 05:00:00 GMT',
	               '-cache-control' => 'no-store, no-cache, must-revalidate, max-age=0',
	               '-pragma'        => 'no-cache'),
	             start_html( '-onload' => 'setFocus()',
	                         '-title'  => $title, 
	                         '-style'  => {'-type' => 'text/css',
	                                       '-src' => '/factslap/c-s-s/link.css'},
	                         '-script' => [{'-src' => $jqurl,
	                                       '-language' => 'JavaScript',
	                                       '-type' => 'text/javascript'},
	                                       {'-src' => $jqvurl,
	                                       '-language' => 'JavaScript',
	                                       '-type' => 'text/javascript'},
	                                       {'-src' => $jlinkurl,
	                                       '-language' => 'JavaScript',
	                                       '-type' => 'text/javascript'}],
	                         '-marginwidth' => '0',
	                         '-marginheight' => '0',
	                         '-bgcolor' => '#FFFFFF'),
	                    div({-id=>'titleimage'},
	                    	a({-href=>'/factslap/', -id=>'factlink'},
	                       img({-src=>'/factslap/c-s-s/factslap.jpg',
	                    	      -label=>'Fact Slap',
	                    	      -height=>'66',
	                    	      -width=>'249'}))),
	                    $text,
	                   div({-class=>'footer'}, 'comments *at* factslap.com') .
	     	       end_html;
	
}


##
# printRedirect
# ---------
# This subroutine prints out a redirect to the user's browser, so they 
# will be redirect to a given site.
#
# Requires: a URL
# 
##
sub printRedirect
{
	my ($url) = @_;
	
	my $query = new CGI;
	
	print $query->redirect($url);

}


##
# getURL
# -------------
# Given a short name, returns a URL, modified time, expires time, created_by, and is_active
# Requires: shortname
# Returns: an array of database rows with the hash:
#          url
#          modified time
#          expries time
#          created_by
#          is_active flag
##
sub getURL
{
		my ($shortname) = @_;
    my ($sth,@rows);
    $sth = $dbh->prepare("SELECT url, modified_time, expires_time, created_by, is_active, ip_address
                          FROM linkbyname
                          WHERE shortname = ?");
                                  
    $sth->execute($shortname);
    
    while (my @row = $sth->fetchrow_array) {
    	if (!defined($row[0])) {
    		$row[0] = '';
    	}
      push @rows, {'url'           => $row[0],
                   'modified_time' => $row[1],
                   'expires_time'  => $row[2],
                   'created_by'    => $row[3],
                   'is_active'     => $row[4],
                   'ip_address'    => $row[5]
                  };
    }

    return (@rows) ? @rows : undef;
}

##
# getShortname
# -------------
# Given a url, and expires time, returns the shortname.
# It will not return an index number if the time is expired
# Requires: a url
# Returns:  (0, '', shortname) on success, (1, error message, undef) on error
##
sub getShortname
{
		my ($url) = @_;
    my ($sth,@rows);
    my $error_code = 0;
    my $error_mess = '';
    my $shortname = '';
    $sth = $dbh->prepare("SELECT shortname
                          FROM linkbyname
                          WHERE url = ?
                          AND expires_time > NOW()");
                                  
    $sth->execute($url);
    
    if ($@) {
         $error_code = 1;
         $error_mess = $@;
    }

    while (my @row = $sth->fetchrow_array) {
      $shortname= $row[0];
    }
    
    return ($error_code,$error_mess,$shortname);
}


##
# updateURL
# --------------
# Sets a URL's expires time that is already entered in the database.
# Returns an error if the update wasn't successful.
#
# NOTE: This may not be needed, will remove later.
#
##
sub updateURL
{
	my ($url,$expires_time) = @_;
	my $error_code = 0;
	my $error_mess = '';
	my $shortname = '';

	($error_code,$error_mess,$shortname) = getIndex($url);
	
	if ($shortname != 0 && $shortname != '') {  # there is already an index for this one

	     $sth = $dbh->prepare("UPDATE linkbyname
                             SET expires_time=?,
                                 modified_time=NOW()
                             WHERE url=?
                             AND expires_time > NOW()");
     
       eval {
         $sth->execute($expires_time,$url);
       };
     
       if ($@) {
         $error_code = 1;
         $error_mess = $@;
       }
       
       ($error_code,$error_mess,$shortname) = getIndex($url); # double-check to make sure link didn't expire

       $sth->finish();
  }       
	
	return ($error_code,$error_mess,$shortname);
}



##
# replaceOldURL
# --------------
# Tries to replace an old expired with a new one. Returns an error if it
# couldn't succeed.
# random_number just allows us to select one of the old URLs
#
# NOTE: This may not be needed, will remove later.
#
##
sub replaceOldURL
{
	my ($url,$expires_time,$random_number) = @_;
	my $error_code = 0;
	my $error_mess = '';
	my $link_id = '';
  my ($sth,@rows);
  $random_number++; #makes sure we don't have a negative array index

    $sth = $dbh->prepare("SELECT link_id
                          FROM links
                          WHERE expires_time < NOW()
                          LIMIT ?");
                                  
    $sth->execute($random_number);
    
    while (my @row = $sth->fetchrow_array) {
    	if (!defined($row[0])) {
    		$row[0] = '';
    	}
      push @rows, {'link_id'   => $row[0]
                  };
    }
    
    $sth->finish();

		if (scalar @rows >= $random_number) {
				$link_id = $rows[$random_number-1]->{'link_id'};
	     $sth = $dbh->prepare("UPDATE links
                             SET url=?,
                                 modified_time=NOW(),
                                 expires_time=?
                             WHERE link_id=?");
     
       eval {
         $sth->execute($url,$expires_time,$link_id);
       };
     
       if ($@) {
         $error_code = 1;
         $error_mess = $@;
       }
       
       $sth->finish();
		}
	return ($error_code,$error_mess,$link_id);
}


##
# saveNumberNameURL
# --------------
# Saves a new numbered URL into the database. This will save the number URL into the linkbyname
# table, then also save it into the linkbyname table. If the name already exists, it will
# attempt to try a different ID until the link can be entered.
#
# The shortname and the baseid are the same: the decimal id encoded in base62
#
# Requires: url, expires time (or ''), created_by
# Returns : (0, '', shortname) on success, (1, error mess, undef) on error
##
sub saveNumberNameURL
{
	my ($url,$expires_time,$created_by,$ip_address) = @_;
	my $error_code = 0;
	my $error_mess = '';
	my $decid = '';
	my $baseid = '';
	my $checkurl = undef;
	
	# Here we try each id until we find one that's not taken
	# We save to the number database table first to get an id, then check to make sure that the
	# base-encoded id doesn't already exist in the linkbyname table.
	# Then we enter the id into linkbyname
	while (!$error_code) { 
		($error_code,$error_mess,$decid) = saveNumberURL($url,$expires_time,$created_by,$ip_address);
		
		$baseid = convertDecToBase($decid);
	
		if (!$error_code) { 
			($checkurl,@rows) = getURL($baseid);
			
			if (!defined($checkurl)) { # if the checkurl is not defined then it's safe to add it
				($error_code,$error_mess) = saveNameURL($baseid,$url,$expires_time,$created_by,$ip_address);
				last;
			}
		}	
	}
	
	return ($error_code,$error_mess,$baseid);
}


##
# saveNumberURL
# -------------
# Saves a new numbered URL into the database. This only saves the raw linkbynumber data into the
# table.
#
# Requires: url, expires time (or ''), created_by
# Returns : (0, '', id number) on success, (1, error mess, undef) on error
##
sub saveNumberURL
{
	my ($url,$expires_time,$created_by,$ip_address) = @_;
	my $error_code = 0;
	my $error_mess = '';
	my $id = '';
	
	if ($expires_time eq '') {
		$expires_time = 'NULL';
	}
	
	$sth = $dbh->prepare("INSERT INTO linkbynumber (url,modified_time,expires_time,created_by,ip_address)
												 VALUES (?,NOW(),?,?,?)");
 
	eval {
		$sth->execute($url,$expires_time,$created_by,$ip_address);
		$id = $dbh->{mysql_insertid};
	};
 
	if ($@) {
		$error_code = 1;
		$error_mess = $@;
	}
	 
	$sth->finish();

	return ($error_code,$error_mess,$id);
}

##
# saveNameURL
# --------------
# Saves a new shortnamed URL into the database. This does not check to make sure the 
# shortname is already in the database; while this will return an error it will be up
# to the calling script to do the checking beforehand.
#
# Requires: shortname, url, expires time (or ''), created_by
# Returns : (0, '') on success, (1, error mess) on error
##
sub saveNameURL
{
	my ($shortname,$url,$expires_time,$created_by,$ip_address) = @_;
	my $error_code = 0;
	my $error_mess = '';
	
	if ($expires_time eq '') {
		$expires_time = 'NULL';
	}
	
	     $sth = $dbh->prepare("INSERT INTO linkbyname (shortname,url,expires_time,created_by,ip_address)
                             VALUES (?,?,?,?,?)");
     
       eval {
         $sth->execute($shortname,$url,$expires_time,$created_by,$ip_address);
       };
     
       if ($@) {
         $error_code = 1;
         $error_mess = $@;
       }
       
       $sth->finish();
	
	return ($error_code,$error_mess);
}


##
# saveNumberURLRandom
# -------------
# Saves a number URL with a more random number. This helps make sure no one
# can guess it.
#
# Note: This may not be needed. Will remove later.
# 
# Requires: url, created_by, expires time or '', random number
# Returns : (0,'',id number) on success, (1, error mess, undef) on error
##
sub saveURLRandom
{
	my ($url,$created_by,$expires_time,$random_number,$ip_address) = @_;
	my $error_code = 0;
	my $error_mess = '';
	my $link_id = '';
	
	($error_code,$error_mess) = savePlaceholder($random_number);

	if ($error_code == 0) {
		($error_code,$error_mess,$link_id) = saveNumberURL($url,$expires_time,$created_by,$ip_address);
	}

	return ($error_code,$error_mess,$link_id);
}



##
# savePlaceholder
# --------------
# Saves a blank record into the number database, with an expired URL
# These placeholders will be used to make sure no one can guess what the next id will be.
#
# Note: This may not be needed. Will remove later.
#
##
sub savePlaceholder
{
	my ($random_number) = @_;
	my $error_code = 0;
	my $error_mess = '';
	my @values = ();
	
	for (my $i = 0; $i < $random_number; $i++) {
		push @values, "('-',NOW(),date_sub(NOW(), interval 10 year))";
	}
	
	if ($random_number > 0) {
	     $sth = $dbh->prepare("INSERT INTO links (url,modified_time,expires_time)
                             VALUES " . join(', ', @values));
     
       eval {
         $sth->execute();
       };
     
       if ($@) {
         $error_code = 1;
         $error_mess = $@;
       }
	
			 $sth->finish();
	}
	
	return ($error_code,$error_mess);
}



##
# convertDecToBase
# ----------------
# Converts a decimal number to a base62 number
##
sub convertDecToBase
{
	my ($decnum) = @_;
	
	dig(@basedigits);

	return cnv($decnum,10,62);
}
##


##
# convertBaseToDec
# ----------------
# Converts a base62 number to a dec number
##
sub convertBaseToDec
{
	my ($basenum) = @_;
	
	dig(@basedigits);

	return cnv($basenum,62,10);
}


##
# checkAndSetParams
# -----------------
# Checks to make sure params are set correctly.
# Requires: url, remote_user, expires time in days
##
sub checkAndSetParams
{
	my ($url,$is_generated,$shortname,$remote_user,$expires_time,$ip_address) = @_;
	my $iret = 0;
	my $mess = '';
	my ($db_expires_time, $hr_expires_time);
	
	
	# remove extra characters from the beginning and end of the URL
	$url =~ s/^\s+//g;
	$url =~ s/\s+$//g;
	$url =~ s/^\t+//g;
	$url =~ s/\t+$//g;
	$url =~ s/^<+//g;
	$url =~ s/<+$//g;
	
	if (!defined($url)) {
		$iret = 1;
		$mess = 'No URL was entered';
	}
	elsif ($url eq '') {
		$iret = 1;
		$mess = 'No URL was entered';
	}
	elsif (!defined($expires_time)) {
		$iret = 1;
		$mess = 'No Expires time was entered';
	}
	elsif ($expires_time eq '') {
		$iret = 1;
		$mess = 'No Expires time was entered';
	}
	elsif (!defined($is_generated)) {
		$iret = 1;
		$mess = 'No selection for generating a query was made';
	}
	elsif ($is_generated and !defined($shortname)) {
		$iret = 1;
		$mess = 'No short name was entered';
	}
	elsif ($remote_user eq '' or !defined($remote_user)) {
		#$iret = 1;
		#$mess = 'No user is logged in';
	}
	elsif ($is_generated and length($shortname) < 4) {
		$iret = 1;
		$mess = 'The name you chose should be at least 4 characters long';
	}
	elsif (!($RE{URI}{HTTP}->matches($url))) { # check to make sure URL is valid
		$iret = 1;
		$mess = 'The URL you entered was not typed correctly. Make sure you have the correct address and try it again.';
	}
	elsif ($url =~ m/^[\s\t]*?http:\/\/www\.factslap\.com.*?$/ or $url =~ m/^[\s\t]*?http:\/\/factslap\.com.*?$/) {
		$iret = 1;
		$mess = 'Are you nuts? You can\'t slap a fact back to the factslap!';
	}
	
	

	
#	if (!($url =~ m/^http:\/\//) && !($url =~ m/^https:\/\//)) {
#		$url = 'http://' . $url;
#	}
	

	
	
	if ($iret == 0) {
		($db_expires_time,$hr_expires_time) = setExpiresTime($expires_time);
		
		# change invalid characters to underscores
		if ($is_generated) {
			$shortname =~ s/[^0-9A-Za-z.-_+]/_/g;
		}
		
	}
	
	return ($iret,$mess,$url,$is_generated,$shortname,$db_expires_time,$hr_expires_time,$remote_user,$ip_address);
}

##
# setExpiresTime
# --------------
# Sets expires time to something readable by humans and the database
##
sub setExpiresTime
{
	my ($expires_time) = @_;
	
	# convert expires_time (in days) to seconds
	my $ex_seconds = ($expires_time * 86400);
	
	my $db_expires_time = strftime("%Y:%m:%d:%H:%M:%S", localtime(time+$ex_seconds));
	
	my $hr_expires_time = strftime("%m %d, %Y %H:%M:%S", localtime(time+$ex_seconds));

	return ($db_expires_time, $hr_expires_time);
}


##
# scrunch
# -------
# Takes a long line of text, and if it's over a certain number of characters, puts a ...
# in the middle of it while truncating it.
##
sub scrunch
{
	my ($text) = @_;
	my $newtext = '';
	
	if (length($text) > 70) {
		$newtext = substr($text,0,40) . '&#8230;[snip]&#8230;' . substr($text,length($text)-15,15) 
	}
	else {
		$newtext = $text;
	}

	return $newtext;
}


##
# All good packages return 1;
##
1;

__END__

##

