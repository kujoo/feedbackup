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

my $baseuri  = 'http://twitter.com/';
my $charset  = 'utf-8'; # not use
my $timezone = 'Asia/Tokyo'; # or local
my $waitsec  = 3;
my $max_loop = 160; # or Twitter-Spec

sub new {
    my $class = shift;
    my $username = shift
        or return undef, 'please specify twitter-username.';
    my $tz   = shift; if($tz)   { $timezone = $tz; }
    my $wait = shift; if($wait) { $waitsec  = $wait; }
    my $loop = shift; if($loop) { $max_loop = $loop; }
    my($rssuri, $iconuri) = &__get_rss_icon($username)
        or return undef, 'could not get rss-feed.';
    my $obj = {
        username => $username,
        rss      => $rssuri  ? $rssuri  : undef,
        icon     => $iconuri ? $iconuri : undef,
    };
    bless $obj, $class;
    return $obj;
}

sub rss_content {
    my $self = shift;
    my $uri  = $self->{rss};
    my $page = shift;
    if($page) { $uri .= '?page='.$page; }
    my $xtpp = XML::TreePP->new(force_array => ["item"]) or return;
    my $rss  = $xtpp->parsehttp(GET => $uri) or return;
    my $item = $rss->{rss}->{channel}->{item} or return;
    return $item;
}

sub date {
    my $self  = shift;
    my $date1 = shift;
    my $date2 = shift;
    unless($date1) {
        $date1 = DateTime->now(time_zone => $timezone);
        $date1 = &__set_day_of_last($date1);
    }
    unless($date2) {
        $date2 = DateTime->now(time_zone => $timezone);
        $date2 = &__set_day_of_first($date2);
    }
    my $start = $date1;
    my $end   = $date2;
    if($date1 < $date2) { $start = $date2; $end = $date1; }

    my $twit;
    my $r_rep = '\@(\w+)';
    my $r_tag = '#\w{2,}';

    for(my $i = 1; $i < $max_loop; $i++) {
        my $rss = $self->rss_content($i);
        unless($rss) { last; }
        foreach(@$rss) {
            my $dt = &__conv_timestamp($_->{pubDate});
            if($dt < $end) {
                return $twit, $end, $start, $i;
            }
            my $link = $_->{link};
            my $text = HTML::Entities::decode($_->{title});
            $text =~ s|^$self->{username}: ||;

sleep($waitsec); ### wait

            my $msg = $text;
            $msg =~ s/</&lt;/g;
            $msg =~ s/>/&gt;/g;
            $msg =~ s/"/&quot;/g;
            my($tag, $reply_user, $reply_uri);
            foreach my $t ($msg =~ m/$r_tag/g) {
                foreach(@$tag) { if($_ eq $t) { undef $t; last; } }
                if($t) { push(@$tag, $t); }
            }
            foreach my $r ($msg =~ m/$r_rep/g) {
                foreach(@$reply_user) { if($_ eq $r) { undef $r; last; } }
                if($r) { push(@$reply_user, $r); }
            }
            if($reply_user) { $reply_uri = &__get_reply(@$reply_user[0], $link); }
            $msg =~ s|$r_rep|\@<a href\="@{[&__chk_reply($1, $reply_uri)]}">$1</a>|g;
            $msg =~ s|$r_tag|<a href\="$baseuri#search\?q\=@{[uri_escape_utf8($&)]}">$&</a>|g;

            if($dt <= $start) {
                push(@$twit, {
                    text => $text,
                    msg  => $msg,
                    link => $link,
                    date => $dt->strftime('%Y/%m/%d'),
                    time => $dt->strftime('%H:%M:%S'),
                    timezone => $timezone,
                    datetime => $dt,
                    tag        => $tag ? $tag : undef,
                    reply      => $reply_uri  ? $reply_uri  : undef,
                    reply_user => $reply_user ? $reply_user : undef,
                });
            }
        }
    }
    return $twit, $end, $start;
}

sub daysago {
    my $self  = shift;
    my $days  = shift;
    my $today = shift;
    unless($days)  { $days  = 1; }
    unless($today) { $today = "-"; }

    my $start = DateTime->now(time_zone => $timezone);
    my $end   = DateTime->now(time_zone => $timezone);
    unless($today =~ m/^today$/i) {
        $start->subtract(days => 1);
        $end->subtract(days => 1);
    }
    if(--$days > 0) { $end->subtract(days => $days); }

    $start = &__set_day_of_last($start, $timezone);
    $end   = &__set_day_of_first($end, $timezone);
    return $self->date($start, $end);
}

sub weeksago {
    my $self = shift;
    my $weeks = shift;
    my $today = shift;
    unless($weeks) { $weeks = 1; }
    unless($today) { $today = "-"; }
    return $self->daysago($weeks * 7, $today);
}

sub datelinechange { # malfunction
    my $self = shift;
    return $self;
}

sub timezonechange {
    my $self = shift;
    my $tz   = shift or return;
    $timezone = $tz;
    return $self;
}

sub waitchange {
    my $self = shift;
    my $wait = shift or return;
    $waitsec = $wait;
    return $self;
}

sub loopchange {
    my $self = shift;
    my $loop   = shift or return;
    $max_loop = $loop;
    return $self;
}

sub __get_rss_icon {
    my $id   = shift or return;
    my $uri  = new URI($baseuri.$id);
    my $icon = scraper {
        process 'div h2 a img', 'icon' => '@src';
        result 'icon';
    }->scrape($uri);
    my $rss = scraper {
        process 'html head link', 'rss[]' => '@href';
        result 'rss';
    }->scrape($uri);
    foreach(@$rss) {
        if($_ =~ /^($baseuri)statuses\/user_timeline\/\d+\.rss$/) {
            return $_, $icon;
        }
    }
}

sub __get_reply {
    my $user  = shift or return;
    my $entry = shift or return;
    my $uri   = new URI($entry);
    my $link = scraper {
        process 'span span.entry-meta a', 'link[]' => '@href';
        result 'link';
    }->scrape($uri);
    foreach(@$link) {
        if($_ =~ /^$baseuri$user\/status\/\d+$/) {
            return $_;
        }
    }
    return "";
}

sub __chk_reply {
    my $user  = shift or return;
    my $reply = shift or return $baseuri.$user;
    if($reply =~ /^$baseuri$user\/status\/\d+$/) {
        return $reply;
    }
    return $baseuri.$user;
}

sub __date_diff {
    my $dt1 = shift or return;
    my $dt2 = shift or return;
    my $dur = $dt1->delta_days($dt2);
    my $by = 1;
    if($dt1 < $dt2) { $by = -1; }
    return $by * $dur->in_units('days');
}

sub __set_day_of_first {
    my $dt = shift or return;
    my $date = DateTime->new(
        time_zone => $timezone,
        year  => $dt->year,
        month => $dt->month,
        day   => $dt->day,
    );
    return $date;
}

sub __set_day_of_last {
    my $dt = shift or return;
    my $date = __set_day_of_first($dt);
    $date->add(days => 1);
    $date->subtract(seconds => 1);
    return $date;
}

sub __conv_timestamp {
    my $timestamp = shift or return;
    return DateTime::Format::HTTP->parse_datetime($timestamp)->set_time_zone($timezone);
}

return 1;
