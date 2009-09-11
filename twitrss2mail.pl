#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Encode;
use Config::Pit;
use MIME::Lite;
use MyApp::TwitRead;

    my $input = $ARGV[0] or die 'no input error.';
    unless($input =~ /^\w+$/) { die 'no input error.'; }

    my $tw = MyApp::TwitRead->new($input);
    my($ps, $dt, $dt2) = $tw->daysago(250);
#   my($ps, $dt, $dt2) = $tw->weeksago();

    my $subject = $input.' on Twitter: '.$dt->ymd('/').' - '.$dt2->ymd('/');
    my $msg_html = '<p>'.$subject.'</p>'."\n\n".'<ul>';
    if($ps and $ps->{datetime}) {
        foreach(@$ps) {
            $msg_html .= "<li><a href=\"$_->{link}\">$_->{time}</a>";
            $msg_html .= "　$_->{msg}</li>\n\n";
        }
    } else {
        $msg_html .= '<p>Not twitting about anything. (or, Could not get RSS-feed.)</p>';
    }
    $msg_html .= '</ul>';

    $subject = Encode::encode("MIME-Header-ISO_2022_JP", $subject);
    $msg_html = Encode::encode("utf8", $msg_html); # or iso-2022-jp ?

    my $config = pit_get("personal.server");

    my $mail = MIME::Lite->new(
        From     => $config->{mail},
        To       => $config->{disposablemail},
        Subject  => $subject,
        Data     => $msg_html,
        Type     => 'text/html',
    );
    $mail->attr('content-type.charset' => 'UTF-8');
    $mail->send("sendmail", "/usr/sbin/sendmail -t -oi -oem");

