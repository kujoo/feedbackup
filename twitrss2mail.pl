#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Encode;
use Config::Pit;
use MIME::Lite;
use MyApp::TwitRead;

    my $input = $ARGV[0] or die 'no input error.';
    unless($input =~ /^\w+$/) { die 'invalid input error.'; }

    my $days = $ARGV[1]; unless($days) { $days = 2; }

    my $tw = MyApp::TwitRead->new($input);
    unless($tw) { die 'Not found RSS-feed. (or, Twitter is down.)'; }

    my($ps, $dt, $dt2, $l) = $tw->daysago($days);
#   if($l) { warn 'last page: '.$l."\n"; }

    my $subject = "$input on Twitter: ".$dt2->ymd('/').' - '.$dt->ymd('/');
    my $msg_html = "<p>$subject</p>\n\n";
    my $date = "";
    if($ps) {
        foreach(@$ps) {
            if($_->{date} ne $date) {
                if($date) { $msg_html .= "</ul>\n"; }
                $date = $_->{date};
                $msg_html .= "<p>$date</p>\n<ul>\n";
            }
            $msg_html .= "<li><a href=\"$_->{link}\">$_->{time}</a>　$_->{msg}</li>\n";
        }
        $msg_html .= '</ul>';
    } else {
        $msg_html .= "<p>Not twitting about anything. (or, Could not get RSS-feed.)</p>\n";
    }

    $subject = Encode::encode("MIME-Header-ISO_2022_JP", $subject);
    $msg_html = Encode::encode("utf8", $msg_html); # or iso-2022-jp ?

    my $config = pit_get("personal.server");

    my $mail = MIME::Lite->new(
        From    => $config->{mail},
        To      => $config->{disposablemail},
        Subject => $subject,
        Data    => $msg_html,
        Type    => 'text/html',
    );
    $mail->attr('content-type.charset' => 'UTF-8');
    $mail->send("sendmail", "/usr/sbin/sendmail -t -oi -oem");

#   print $msg_html;

