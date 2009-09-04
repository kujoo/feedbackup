#!/usr/bin/perl
use strict;
use warnings;
use utf8;
#use CGI;
#use CGI::Carp qw(fatalsToBrowser);
use Encode;
#use open ':utf8';
#  binmode STDIN, ":utf8";
  binmode STDOUT, ":utf8";
#use Config::Pit;
#use LWP::UserAgent;
#use MIME::Base64;
use XML::TreePP;
use HTML::Entities;
use Web::Scraper;
use URI;
use DateTime::Format::HTTP;
#use Data::Dumper;

    my $input = $ARGV[0] or die 'no input error.';
    unless($input =~ /^\w+$/) {
        exit;
    }
    my $un = $input;
    my($urirss, $tw, $ic) = &get_rss_uri($un) or die('doesnot get user-code.');

    my $i;
    for($i = 1; $i < 999; $i++) {
        my $twit = &get_rss_twit($urirss, $i);
        unless($twit) { last; }
        print '<table>';
        foreach(@$twit) {
            my($dt, $ti) = &get_date_timestamp($_->{pubDate});
            my $ps = HTML::Entities::decode($_->{title});
            my $lk = $_->{link};
            print<<"EOD";
$dt
<tr><td><a href="$tw"><img src="$ic" border="0" width="48"></a></td><td><a href="$tw">$un</a></td><td>$ti</td><td>$ps</td><td><a href="$lk">link</a></td></tr>
EOD
        }
        print '</table>';
    }
    print "\nscraping: $i\n";

    exit;

sub get_rss_uri {
    my $id = shift or return;
    my $turi = 'http://twitter.com/'.$id;
    my $uri = new URI($turi);
    my $ico = scraper {
        process 'div.profile-head div.listable h2 a img', 'ico' => '@src';
        result 'ico';
    }->scrape($uri);
    my $rss = scraper {
        process 'html head link', 'rss[]' => '@href';
        result 'rss';
    }->scrape($uri);
    foreach(@$rss) {
        if($_ =~ /^http:\/\/twitter\.com\/statuses\/user_timeline\/\d+\.rss$/) {
            return $_, $turi, $ico;
        }
    }
    return;
}

sub get_rss_twit {
    my $uri = shift or return;
    my $page = shift or return;
    sleep(7);
    my $xtpp = XML::TreePP->new() or return;
    my $rss = $xtpp->parsehttp(GET => $uri.'?page='.$page) or return;
    my $item = $rss->{rss}->{channel}->{item} or return;
    return $item;
}

sub get_date_timestamp {
    my $timestamp = shift or return;
    my $dt = DateTime::Format::HTTP->parse_datetime($timestamp)->set_time_zone('local');
    my($date, $time) = split(/T/, $dt);
    return $date, $time;
}

