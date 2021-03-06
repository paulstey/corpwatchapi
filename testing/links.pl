#!/usr/bin/perl 

    # Copyright 2009 CorpWatch.org 
    # San Francisco, CA | 94110, USA | Tel: +1-415-641-1633
    # Developed by Greg Michalec and Skye Bender-deMoll
    
    # This program is free software: you can redistribute it and/or modify
    # it under the terms of the GNU General Public License as published by
    # the Free Software Foundation, either version 3 of the License, or
    # (at your option) any later version.

    # This program is distributed in the hope that it will be useful,
    # but WITHOUT ANY WARRANTY; without even the implied warranty of
    # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    # GNU General Public License for more details.

    # You should have received a copy of the GNU General Public License
    # along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
 #-----------------------------
 # This code serves as a viwer for comparing the parsed subsidary results in the database to the original Exhibit 21 filing
 #-----------------------------

use CGI qw/:standard/;
my $cgi = CGI->new();
print $cgi->header();
chdir "/home/dameat/edgarapi/backend/"; #This should be set to the full path of this script
require "common.pl";

our $db;
our $datadir;
my $action = param('action');

print "<html>";

if ($action eq 'index') {
	$checked = param('onlycroc') eq 'on' ? 'checked': '';
	$badchecked = param('bad') eq 'on' ? 'checked': '';
	$emptychecked = param('empty') eq 'on' ? 'checked': '';
	print "<div id='search' style='position: fixed; padding: 10px; right: 20px; top: 20px; background: #9999EE;'><form action='links.pl' method='get'>
	<input type='checkbox' name='onlycroc' $checked>Only show Crocodyl Companies<br/>
	<input type='checkbox' name='bad' $badchecked>Only show badly parsed<br/>
	<input type='checkbox' name='empty' $emptychecked>Only show filings w/o relationships<br/>
	<input type='hidden' name='action' value='index'><input name='search'><input type='submit'></form></div>";
	if ($checked || $badchecked) { 
		$join = " join croc_companies b on b.cik = a.cik and type like '10-K%' ";
		if ($badchecked) { $where = " and parsed_badly = 1 "; }
	}
	if ($emptychecked) {
		$join .= " left join (select filing_id from relationships group by filing_id) r using (filing_id) ";
	}
	if (param('search')) { 
		$search = param('search');
		if ($search =~ /^\d+$/) { 
			$where = " and (filing_id = $search or cik = $search) "
		} else { 
			$where = " and company_name like '%$search%'";
		}
	}
	if ($emptychecked) { $where .= "and r.filing_id is null"; }
	$query = "select filing_id, filename, quarter, year, a.cik, a.company_name from filings a $join where has_sec21 = 1 $where order by company_name limit 1000";
	print "$query<br>";
	$filing = $db->selectall_arrayref("$query") || die "$!";
	foreach my $filing (@$filing) {
		open(FILE, "$datadir/$filing->[3]/$filing->[2]/$filing->[0].sec21");
		my $filename;
		#scan through the Section 21 to locate the file name
		while (<FILE>) { 
			if ($_ =~ /^<FILENAME>(.+)/) {
				$filename = $1;
				last;
			}
		}
		my $path = $filing->[1];
		$path =~ s/\-//g;
		$path =~ s/.{4}$//;
		$onclick = "javascript: parent.htmlsrc.location=\"http://www.sec.gov/Archives/$path/$filename\"; parent.relates.location=\"links.pl?action=lookup&id=$filing->[0]\"; return false;";
		$link = "<a onclick ='$onclick' href='http://www.sec.gov/Archives/$path/$filename'>$filing->[5] ($filing->[4] / $filing->[0])</a><br>\n";
		print $link;
	}
} elsif ($action eq 'lookup') {
	my $sth = $db->prepare("select * from relationships where filing_id = ".param('id')." order by relationship_id") || die "$!";
	$sth->execute();
	print "<table border=1>";
	#if (! $relates[0]) { print "no relationships found"; }
	my $level = 0;
	my $parents = [0];
	while (my $relate =  $sth->fetchrow_hashref()) {
		my $parent = $relate->{hierarchy};
		unless ($parent) { $parent = 0; }
		if ($parent > $parents->[$level]) {
			$level++;
		} elsif ($parent <= $parents->[$level]) {
			while ($parent < $parents->[$level] && $level > 0) {
				$level--;
			}
		}
		$parents->[$level] = $parent;
		print "<tr><td>"."&nbsp;"x($level*4)."$relate->{company_name}</td><td>$relate->{location}</td><td>$relate->{parse_method}</td></tr>\n";
	}
	print "</table>";
} else {
 print "<frameset rows='30%, 70%'>
			<frame name='index' frameborder=1 src='links.pl?action=index'>
			<frameset cols='50%,50%'>
			<frame name='htmlsrc'  frameborder=1 src=''>
			<frame name='relates' frameborder=1 src=''>
			</frameset>
		</frameset>";
}

print "</html>";

