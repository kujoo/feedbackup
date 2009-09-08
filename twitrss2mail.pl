#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Encode;
  binmode STDOUT, ":utf8";
use Data::Dumper;
use Mail::Sender;
#use Mail::Sendmail;
#use Mail::SendEasy;
use MyApp::TwitRead;

    my $input = $ARGV[0] or die 'no input error.';
    unless($input =~ /^\w+$/) {
        die 'no input error.';
    }

    my $tw = MyApp::TwitRead->new($input);
    my $ps = $tw->dayago(1, 'today');

    my $message = "$input said:\n\n";
    foreach(@$ps) {
        $message .= "-$_->{date} $_->{time} $_->{post}\n\t$_->{link}\n\n";
    }
    my $subject = 'Yesterday twitter said.';

    $subject = Encode::encode("MIME-Header-ISO_2022_JP", $subject);
    $message = Encode::encode("iso-2022-jp", $message);

    my $sender = new Mail::Sender { port => '587' };
    $sender->MailMsg({
        headers => ';',
        from    => 'kurihara@kur.sakura.ne.jp',
        to      => 'kurtalk@gmail.com',
        subject => $subject,
        msg     => $message,
        charset => 'ISO-2022-jp',
        ctype   => 'text/plain; charset="iso-2022-jp"',
    });

