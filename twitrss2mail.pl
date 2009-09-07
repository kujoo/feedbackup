#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Encode;
  binmode STDOUT, ":utf8";
use Data::Dumper;
use Mail::SendEasy;
use MyApp::TwitRead;

    my $input = $ARGV[0] or die 'no input error.';
    unless($input =~ /^\w+$/) {
        die 'no input error.';
    }

    my $tw = MyApp::TwitRead->new($input);
    my $ps = $tw->dayago();

    foreach(@$ps) {
        print "-$_->{date} $_->{time} $_->{post} $_->{limk}\n";
    }



