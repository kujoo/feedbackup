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
use URI::Escape;
use DateTime::Format::HTTP;
#use Data::Dumper;

    my $input = $ARGV[0] or die 'no input error.';
    unless($input =~ /^\w+$/) {
        exit;
    }
    my $username = $input;

    my $base = 'http://twitter.com/';
    my($rss, $icon) = &get_uri_rss_icon($base, $username) or die('doesnot get user-code.');

    my($count, $days) = (0, "");
    for(my $i = 1; $i < 999; $i++) {
        my $twit = &get_rss_twit($rss, $i);
        unless($twit) {
            print "</ul>\n";
            $count = $i;
            last;
        }
        foreach(@$twit) {
            my($date, $time) = &get_date_timestamp($_->{pubDate});
            my $link = $_->{link};
            my $post = HTML::Entities::decode($_->{title});
            $post =~ s/^$username: //;
            $post =~ s/\@(\w+)/\@<a href\="@{[&get_uri_reply($link, $base.$1)]}">$1<\/a>/g;
            $post =~ s/#\w+/<a href\="$base#search\?q\=@{[uri_escape_utf8($&)]}">$&<\/a>/g;
            if($days ne $date) {
                if($days) { print "</ul>\n"; }
                print "- $date\n";
                print "<ul>\n";
                $days = $date;
            }
            print<<"EOD";
<li><a href="$link">$time</a> $post</li>
EOD
        }
    }
    print "\nscraping: $count\n";

    exit;

sub get_uri_rss_icon {
    my $base = shift or return;
    my $id = shift or return;
    my $uri = new URI($base.$id);
    my $icon = scraper {
        process 'div h2 a img', 'icon' => '@src';
        result 'icon';
    }->scrape($uri);
    my $rss = scraper {
        process 'html head link', 'rss[]' => '@href';
        result 'rss';
    }->scrape($uri);
    foreach(@$rss) {
        if($_ =~ /^($base)statuses\/user_timeline\/\d+\.rss$/) {
            return $_, $icon;
        }
    }
}

sub get_rss_twit {
    my $base = shift or return;
    my $page = shift or return;
    sleep(7);
    my $xtpp = XML::TreePP->new() or return;
    my $rss = $xtpp->parsehttp(GET => $base.'?page='.$page) or return;
    my $item = $rss->{rss}->{channel}->{item} or return;
    return $item;
}

sub get_date_timestamp {
    my $timestamp = shift or return;
    my $dt = DateTime::Format::HTTP->parse_datetime($timestamp)->set_time_zone('local');
    my($date, $time) = split(/T/, $dt);
    return $date, $time;
}

sub get_uri_reply {
    my $entry = shift or return;
    my $user_tl = shift or return;
    my $uri = new URI($entry);
    my $link = scraper {
        process 'span span.entry-meta a', 'link[]' => '@href';
        result 'link';
    }->scrape($uri);
    foreach(@$link) {
        if($_ =~ /^$user_tl\/status\/\d+$/) {
            return $_;
        }
    }
    return $user_tl;
}

