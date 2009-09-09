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

sub new {
    my $class = shift;
    my $username = shift or die('please specify twitter-username.');
    my $baseuri = 'http://twitter.com/';
    my($rssuri, $iconuri) = &__get_rss_icon($baseuri, $username) or die('doesnot get rss-feed.');
    bless {
        username => $username,
        rssuri   => $rssuri,
        iconuri  => $iconuri ? $iconuri : undef,
        twitter  => $baseuri,
        charset  => 'utf-8', # not use
        waitsec  => 5,
        timezone => 'Asia/Tokyo', # or local
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
    return $item;
}

sub date {
    my $self = shift;
    my $date1 = shift;
    my $date2 = shift;
    my $tz = shift;
    my $max = shift;
    unless($max) { $max = 99; }
    unless($tz) { $tz = $self->{timezone}; }
    unless($date1) {
        $date1 = DateTime->now(time_zone => $tz);
        $date1 = &__set_day_of_last($date1, $tz);
    }
    unless($date2) {
        $date2 = DateTime->now(time_zone => $tz);
        $date2 = &__set_day_of_first($date2, $tz);
    }
    my $start = $date1;
    my $end   = $date2;
    if($date1 < $date2) { $start = $date2; $end = $date1; }

    my $twit;
    my $m_rep = '\@(\w+)';
    my $m_tag = '#\S+';

    for(my $i = 1; $i < $max; $i++) {
        my $rss = $self->rss_content($i);
        unless($rss) { last; }
### wait
sleep($self->{waitsec});
        foreach(@$rss) {
            my $dt = &__conv_timestamp($_->{pubDate}, $tz);
            if($dt < $end) {
                return $twit, $end, $start;
            }
            my $link = $_->{link};
            my $text = HTML::Entities::decode($_->{title});
            $text =~ s|^$self->{username}: ||;
            my $msg = $text;

            my($tag, $reply_user, $reply_uri);
            foreach my $t ($msg =~ m/$m_tag/g) {
                foreach(@$tag) { if($_ eq $t) { undef $t; last; } }
                if($t) { push(@$tag, $t); }
            }
            foreach my $r ($msg =~ m/$m_rep/g) {
                foreach(@$reply_user) { if($_ eq $r) { undef $r; last; } }
                if($r) { push(@$reply_user, $r); }
            }
### wait
sleep($self->{waitsec});
            if($reply_user) { $reply_uri = &__get_reply($self->{twitter}.@$reply_user[0], $link); }
            $msg =~ s|$m_rep|\@<a href\="@{[&__chk_reply($self->{twitter}.$1, $reply_uri)]}">$1</a>|g;
            $msg =~ s|$m_tag|<a href\="$self->{twitter}#search\?q\=@{[uri_escape_utf8($&)]}">$&</a>|g;
            if($dt <= $start) {
                push(@$twit, {
                    text => $text,
                    msg  => $msg,
                    link => $link,
                    date => $dt->strftime('%Y/%m/%d'),
                    time => $dt->strftime('%H:%M:%S'),
                    timezone => $self->{timezone},
                    datetime => $dt,
                    tag  => $tag ? $tag : undef,
                    reply      => $reply_uri  ? $reply_uri  : undef,
                    reply_user => $reply_user ? $reply_user : undef,
                });
            }
        }
    }
    return $twit, $end, $start;
}

sub daysago {
    my $self = shift;
    my $days = shift;
    unless($days) { $days = 1; }
    my $today = shift;
    unless($today) { $today = "-"; }
    my $tz = shift;
    unless($tz) { $tz = $self->{timezone}; }

    my $start = DateTime->now(time_zone => $tz);
    my $end   = DateTime->now(time_zone => $tz);
    unless($today =~ m/^today$/i) {
        $start->subtract(days => 1);
        $end->subtract(days => 1);
    }
    if(--$days > 0) { $end->subtract(days => $days); }

    $start = &__set_day_of_last($start, $tz);
    $end   = &__set_day_of_first($end, $tz);
    return $self->date($start, $end);
}

sub weeksago {
    my $self = shift;
    my $weeks = shift;
    unless($weeks) { $weeks = 1; }
    my $today = shift;
    unless($today) { $today = ""; }
    return $self->daysago($weeks * 7, $today);
}

sub datelinechange { # malfunction
    my $self = shift;
    return $self;
}

sub timezonechange { # malfunction
    my $self = shift;
    my $tz = shift or return;
    $self->{timezone} = $tz;
    return $self;
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
    my $user_tl = shift or return;
    my $entry = shift or return;
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
    return "";
}

sub __chk_reply {
    my $user_tl = shift or return;
    my $reply = shift or return $user_tl;
    if($reply =~ /^$user_tl\/status\/\d+$/) {
        return $reply;
    }
    return $user_tl;
}

sub __date_diff {
    my $dt1 = shift or return;
    my $dt2 = shift or return;
    my $dur = $dt1->delta_days($dt2);
    return $dur->in_units('days');
}

sub __set_day_of_first {
    my $dt = shift or return;
    my $tz = shift;
    unless($tz) { $tz = 'local'; }
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
    unless($tz) { $tz = 'local'; }
    my $date = __set_day_of_first($dt, $tz);
    $date->add(days => 1);
    $date->subtract(seconds => 1);
    return $date;
}

sub __conv_timestamp {
    my $timestamp = shift or return;
    my $tz = shift;
    unless($tz) { $tz = 'local'; }
    return DateTime::Format::HTTP->parse_datetime($timestamp)->set_time_zone($tz);
}

return 1;
