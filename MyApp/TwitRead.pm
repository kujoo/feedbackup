package MyApp::TwitRead;

use strict;
use warnings;
use utf8;
#use Carp qw(croak);
#use Encode;
use XML::TreePP;
use HTML::Entities;
use Web::Scraper;
use URI;
use URI::Escape;
use DateTime;
use DateTime::Format::HTTP;

my $__time_zone = 'local';

sub new {
    my $class = shift;
    my $username = shift
        or die('please specify twitter-username.');
    my $baseuri = 'http://twitter.com/';
    my($rssuri, $iconuri) = &__get_rss_icon($baseuri, $username)
        or die('doesnot get rss-feed.');
    bless {
        username => $username,
        rssuri   => $rssuri,
        iconuri  => $iconuri,
        twitter  => $baseuri,
        charset  => 'utf-8',
        waitsec  => 3,
        timezone => $__time_zone,
    }, $class;
}

sub icon {
    my $self = shift;
    return $self->{iconuri};
}

sub rss {
    my $self = shift;
    return $self->{rssuri};
}

sub rss_content {
    my $self = shift;
    my $uri = $self->{rssuri};
    my $page = shift;
    if($page) { $uri .= '?page='.$page; }
    my $xtpp = XML::TreePP->new() or return;
    my $rss = $xtpp->parsehttp(GET => $uri) or return;
    my $item = $rss->{rss}->{channel}->{item} or return;
    sleep($self->{waitsec});
    return $item;
}

sub date {
    my $self = shift;
    my $date1 = shift;
    my $date2 = shift;
    my $tz = shift;
    my $max = shift;
    unless($max) { $max = 99; }
    unless($tz) { $tz = $__time_zone; }
    unless($date1) {
        $date1 = DateTime->now(time_zone => $tz);
        $date1 = &__set_day_of_last($date1);
    }
    unless($date2) {
        $date2 = DateTime->now(time_zone => $tz);
        $date2 = &__set_day_of_first($date2);
    }
    my $start = $date1;
    my $end   = $date2;
    if($date1 < $date2) {
        $start = $date2;
        $end   = $date1;
    }

    my $twit;

    for(my $i = 1; $i < $max; $i++) {
        my $rss = $self->rss_content($i);
        unless($rss) { last; }
        foreach(@$rss) {
            my $dt = &__conv_timestamp($_->{pubDate});
            if($dt < $end) { return $twit; }
            my $link = $_->{link};
            my $post = HTML::Entities::decode($_->{title});
            $post =~ s|^$self->{username}: ||;
            $post =~ s|\@(\w+)|\@<a href\="@{[&__get_reply($link, $self->{twitter}.$1)]}">$1</a>|g;
            $post =~ s|#\S+|<a href\="$self->{twitter}#search\?q\=@{[uri_escape_utf8($&)]}">$&</a>|g;
            if($dt <= $start) {
                push(@$twit, {
                    post => $post,
                    link => $link,
                    date => $dt->strftime('%Y/%m/%d'),
                    time => $dt->strftime('%H:%M:%S'),
                });
            }
        }
    }
    return $twit;
}

sub dayago {
    my $self = shift;
    my $days = shift;
    unless($days) { $days = 1; }
    my $today = shift;
    unless($today) { $today = "-"; }
    my $tz = shift;
    unless($tz) { $tz = $__time_zone; }

    my $start = DateTime->now(time_zone => $tz);
    my $end   = DateTime->now(time_zone => $tz);
    unless($today =~ m/^today$/i) {
        $start->subtract(days => 1);
        $end->subtract(days => 1);
    }
    if($days > 0) { $end->subtract(days => $days); }

    $start = &__set_day_of_last($start);
    $end   = &__set_day_of_first($end);
    return $self->date($start, $end);
}

sub weekago {
    my $self = shift;
    my $weeks = shift;
    unless($weeks) { $weeks = 1; }
    my $today = shift;
    unless($today) { $today = ""; }
    return $self->dayago($weeks * 7, $today);
}

sub datelinechange {
    my $self = shift;
    return;
}

sub __get_rss_icon {
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

sub __get_reply {
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

sub __date_diff {
    my $dt1 = shift or return;
    my $dt2 = shift or return;
#   my $tz = shift;
#   unless($tz) { $tz = $__time_zone; }
#   my($y, $m, $d) = split(/-/, $date1);
#   my $dt1 = DateTime->new(time_zone => $tz, year => $y, month => $m, day => $d);
#   ($y, $m, $d) = split(/-/, $date2);
#   my $dt2 = DateTime->new(time_zone => $tz, year => $y, month => $m, day => $d);
    my $dur = $dt1->delta_days($dt2);
    return $dur->in_units('days');
}

sub __set_day_of_first {
    my $dt = shift or return;
    my $tz = shift;
    unless($tz) { $tz = $__time_zone; }
    my $date = DateTime->new(
        time_zone => $tz,
        year  => $dt->year,
        month => $dt->month,
        day   => $dt->day);
    return $date;
}

sub __set_day_of_last {
    my $dt = shift or return;
    my $tz = shift;
    unless($tz) { $tz = $__time_zone; }
    my $date = __set_day_of_first($dt, $tz);
    $date->add(days => 1);
    $date->subtract(seconds => 1);
    return $date;
}

sub __conv_timestamp {
    my $timestamp = shift or return;
    my $tz = shift;
    unless($tz) { $tz = $__time_zone; }
    return DateTime::Format::HTTP->parse_datetime($timestamp)->set_time_zone($tz);
}

return 1;
