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
#use HTML::TagParser;
use Web::Scraper;
use URI;
#use Data::Dumper;

    my $input = $ARGV[0] or die 'no input error.';
    unless($input =~ /^\w+$/) {
        exit;
    }
    my $username = $input;

    my $i;
    for($i = 1; $i < 999; $i++) {
        my $twit = &do_scrape_twit($username, $i);
        unless($twit) { last; }
        foreach(@$twit) {
            print $_->{uri}."\t".$_->{date}."\t".
                  $_->{msg}."\n";
        }
    }
    print "\nscraping: $i\n";

    exit;

sub do_scrape_twit {
    my $id = shift or return;
    my $page = shift or return;
    my $uri = new URI('http://twitter.com/'.$id.'?page='.$page);
    sleep(5);
    return scraper {
        process 'ol.statuses li span.status-body',
            'twit[]' => scraper {
                process 'span.entry-content', msg => 'TEXT';
                process 'span a.entry-date', uri => '@href';
                process 'span a.entry-date span.published', date => 'TEXT';
            };
        result 'twit';
    }->scrape($uri);
}

