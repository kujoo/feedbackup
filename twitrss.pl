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
#use Data::Dumper;

    my $input = $ARGV[0] or die 'no input error.';
    unless($input =~ /^\w+$/) {
        exit;
    }
    my $username = $input;
    my $urirss = &get_uri_rss($username) or die('doesnot get user-code.');

    my $i;
    for($i = 1; $i < 999; $i++) {
        my $twit = &do_scrape_twit_rss($urirss, $i);
        unless($twit) { last; }
        foreach(@$twit) {
            print $_->{pubDate}."\t".$_->{link}."\t".
                  HTML::Entities::decode($_->{title})."\n";
        }
    }
    print "\nscraping: $i\n";

    exit;

sub get_uri_rss {
    my $id = shift or return;
    my $uri = new URI('http://twitter.com/'.$id);
    my $rss = scraper {
        process 'html head link', 'rss[]' => '@href';
        result 'rss';
    }->scrape($uri);
    foreach(@$rss) {
        if($_ =~ /^http:\/\/twitter\.com\/statuses\/user_timeline\/\d+\.rss$/) {
            return $_;
        }
    }
    return;
}

sub do_scrape_twit_rss {
    my $uri = shift or return;
    my $page = shift or return;
    sleep(8);
    my $xtpp = XML::TreePP->new() or return;
    my $rss = $xtpp->parsehttp(GET => $uri.'?page='.$page) or return;
    my $item = $rss->{rss}->{channel}->{item} or return;
    return $item;
}

