#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Encode;
  binmode STDOUT, ":utf8";
use Data::Dumper;
#use Mail::Sender;
#use Mail::Sendmail;
#use Mail::SendEasy;
use MIME::Lite;
use MyApp::TwitRead;

    my $input = $ARGV[0] or die 'no input error.';
    unless($input =~ /^\w+$/) {
        die 'no input error.';
    }

    my $tw = MyApp::TwitRead->new($input);
    my $ps = $tw->daysago(3);

    my $message = "$input said:\n\n";
    foreach(@$ps) {
        $message .= "-$_->{date} $_->{time} $_->{msg}\n\t$_->{link}\n\n";
    }
    my $subject = 'Yesterday twitter said.';

    print $message;

    $subject = Encode::encode("MIME-Header-ISO_2022_JP", $subject);
    $message = Encode::encode("iso-2022-jp", $message);

    my $mail = MIME::Lite->new(
        From     => 'kujoo@wiir.jp',
        To       => 'kurtalk@gmail.com',
        Subject  => $subject,
        Type     => 'TEXT',
        Data     => $message,
#        Encoding => 'base64',
    );
    $mail->send("sendmail", "/usr/sbin/sendmail -t -oi -oem");

