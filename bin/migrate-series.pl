#!/usr/bin/env perl

use 5.16.0;
use warnings;

use bacds::Scheduler::Util::Db qw/get_dbh/;

my $dbh = get_dbh();

create_series($dbh);
setup_event_templates($dbh);

sub create_series {
    my ($dbh) = @_;

    # from this list here:
    # https://bacds.org/series/
    # and from the currently db of events
    my @series = (
        {
            name => 'Berkeley Contra',
            series_xid => 'BERK-CONTRA',
            frequency => 'first, third and fifth Wednesdays',
            series_url => 'https://bacds.org/series/contra/berkeley_wed/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./contra/berkeley_wed/content.html:
<!--#include virtual="/series/shared/role_name_lr.html" -->
<!--#include virtual="/series/shared/location_gnc.html" -->
<!--#include virtual="/series/shared/time_late_150.html" -->
<!--#include virtual="/series/shared/price_weeknight.html" -->
<!--#include virtual="/series/shared/directions_gnc.html" -->
EOL
            display_text => <<'EOL',
<div class="center">
<h1 class="dance">Berkeley Wednesday (through August 2022 and then) Thursday Contra Dance</h1>
</div>
EOL

        },
        {
            name => 'San Francisco Contra',
            series_xid => 'SF-CONTRA',
            frequency => 'first and third Saturdays',
            series_url => 'https://bacds.org/series/contra/san_francisco/',
            is_deleted => 0,
        },
        {
            name => 'Palo Alto Contra Dance',
            series_xid => 'PA-CONTRA',
            frequency => 'second, fourth and fifth Saturdays',
            series_url => 'https://bacds.org/series/contra/palo_alto/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./contra/palo_alto/content.html:
<!--#include virtual="/series/shared/location_pa.html" -->
<!--#include virtual="/series/shared/time_late_lesson_180.html" -->
<!--#include virtual="/series/shared/price_weekend.html" -->
<!--#include virtual="/series/shared/directions_pa.html" -->
EOL
            display_text => <<'EOL',
<h2 class="dance" align="center">First United Methodist Church of Palo Alto</h2>
<!--#include virtual="/series/shared/role_name_lr.html" -->
EOL
        },
        {
            name => 'Palo Alto Friday English Dance',
            series_xid => 'PA-ENGLISH',
            frequency => 'first Fridays',
            series_url => 'https://bacds.org/series/english/palo_alto/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./english/palo_alto/content.html:
<!--#include virtual="/series/shared/location_sme.html" -->
<!--#include virtual="/series/shared/time_late_lesson.html" -->
<!--#include virtual="/series/shared/price_weekend.html" -->
<!--#include virtual="/series/shared/directions_sme.html" -->
EOL
            display_text => <<'EOL',
<div class="center">
<h2 class="dance">1st Fridays - Saint Mark's Episcopal Church Parish Hall</h2>
</div>
EOL
        },
        {
            name => 'South Bay Contra Dance Series',
            series_xid => 'SB-CONTRA',
            frequency => 'third Sunday afternoons, 3:00–6:00, lesson at 2:30',
            series_url => 'https://bacds.org/series/contra/san_jose/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./contra/san_jose/content.html:
<a target="_blank" href="https://www.facebook.com/groups/SouthBayContraDance/">
    <img border="0" src="/images/logofb.png" width="45" height="45" align=center valign=top alt="Find us on Facebook"></a>&nbsp;
<a target="_blank" href="http://www.meetup.com/South-Bay-Contra-Dance-Meetup" alt="Find us on Meetup">
    <img border="0" src="/images/meetup.jpg" width="70" height="45" align=center valign=top></a>
<!--#include virtual="/series/shared/location_fsj.html" -->
<!--#include virtual="/series/shared/time_aft_180_3.html" -->
<!--#include virtual="/series/shared/price_weekend_sbc.html" -->
<!--#include virtual="/series/shared/directions_fsj.html" -->
EOL
            display_text => <<'EOL',
<div class="center"><h2 class="dance">a welcoming, intergenerational dance on 3rd Sundays</h2></div>
<h1>This series is currently on hiatus.  If you don't see a calendar entry listed below, there is no dance.</h1>
        <div align="center"><table><tr><td><em><ul style="margin-top: 0em;">
            <li>Newcomer's Introduction at 2:30pm
            <li>Take the intro at 2:30 pm and get a 2nd dance Free pass </li>
            <li>Kid-friendly dance before the potluck snack break
            <li>Gender-free calling (Larks/Robins)
        </ul></em></td></tr></table></div>
        <br><a href="mailto:SouthBayContra-info@bacds.org" style="text-decoration:none">
            <input type="button" value="Questions or comments? Email us!"/></a><br><br>

EOL
        },
        {
            name => 'Hayward Contra',
            series_xid => 'HAYWARD-CONTRA',
            frequency => 'fourth and fifth Sunday afternoons of each month, 4:00–7:00, lesson at 3:30',
            is_deleted => 0,
            sidebar => <<'EOL', # ./contra/hayward/content.html:
EOL
            display_text => <<'EOL',
<p>
At present, the Hayward Contra is running independently, not as a BACDS dance.
</p>
<p>
For information about the Hayward Contra series visit <a href="https://sfbaycontra.org">sfbaycontra.org</a>
</p>
EOL
        },
        {
            name => 'Peninsula English (Palo Alto)',
            series_xid => 'PEN-ENGLISH',
            frequency => 'first, third, and fifth Tuesday evenings of each month (with a break from late June through Labor Day).',
            series_url => 'https://bacds.org/series/english/peninsula/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./english/peninsula/content.html:
<!--#include virtual="/series/shared/location_ast.html" -->
<!--#include virtual="/series/shared/time_mid_120.html" -->
<!--#include virtual="/series/shared/price_standard.html" -->
<!--#include virtual="/series/shared/directions_ast.html" -->
EOL
            display_text => <<'EOL',
<div class="center">
<h2 class="dance">1st, 3rd &amp; 5th Tuesdays, September through June<br />
Regular location: All Saints Episcopal, Palo Alto<br />
<br /><br />
<!--
Special October 2015 Location: First Baptist Church, 305 North California Avenue,
Palo Alto, CA - Thursday nights! 
-->
</h2>
</div>
EOL
        },
        {
            name => 'Berkeley English',
            series_xid => 'BERK-ENGLISH',
            frequency => 'second and fourth Wednesday',
            series_url => 'https://bacds.org/series/english/berkeley_wed/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./english/berkeley_wed/content.html:
<a target="_blank" href="http://facebook.com/groups/Berkeley.Wednesday.ECD"><img border="0" src="/images/FindUsOnFacebook.gif" width="175" height="50" alt="Find us on Facebook"></a>
<br />
<a href="/email/?l=berkeley-wed-english" style="text-decoration: none"><input type="button" value="Sign up for our E-mail list" /></a>
<br /><br />

<div align="left">
<p class="location">
<ul>
    <li>When you arrive at the hall, you will have to fill out a form answering
    questions about Covid symptoms. You will not have to provide contact
    information a second time. To see the questions ahead of time, click <a
    href="https://docs.google.com/document/d/1avctu_0x8vZoZ88BQ0eqqoiXe6jjcVvLXEQ7RgYLRtA/edit?usp=sharing">here</a>.</li>
</ul>

<br />
<br />
<br />
<a href="https://www.bacds.org/COVID/">BACDS COVID level and safety precautions</a>
</p>
</div>
<br />
<!--#include virtual="/series/shared/time_special_bwe.html" -->
<!--#include virtual="/series/shared/location_gnc.html" -->
<!--#include virtual="/series/shared/price_weeknight.html" -->
<!--#include virtual="/series/shared/directions_gnc.html" -->
EOL
        display_text => <<'EOL',
<h1 class="dance">Berkeley Wednesday (through August 2022, then) Thursday English Dance</h1>
EOL
        },

        {
            name => 'Berkeley Fourth Saturday Experienced Dance',
            series_xid => 'BERK-EXP-ENGLISH',
            frequency => 'fourth Saturday',
            series_url => 'https://bacds.org/series/english/berkeley_sat/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./english/berkeley_sat/content.html:
<!--#include virtual="/series/shared/location_gnc.html" -->
<!--#include virtual="/series/shared/time_mid_150.html" -->
<!--#include virtual="/series/shared/price_weekend.html" -->
<!--#include virtual="/series/shared/directions_gnc.html" -->
EOL
            display_text => <<'EOL',
<div class="center">
    <h2>
    Christ Church Berkeley
    (formerly known as Grace North Church)<br />
    2138 Cedar (between Shattuck and Oxford) <br />
    </h2>
</div>

<p>
Are you comfortable dancing <b>heys for three</b> and <b>double figures of eight</b>? Do you 
find it satisfying to move in time to the music and to match your fellow dancers surging in a line?
<p>
Welcome to the Fourth Saturday Experienced English Dance!
<p>
We spend some time each evening paying attention to styling, to make the dances go more smoothly and look nicer. Each program includes a few <b>challenging dances</b>, as well as many familiar and favorite dances that we can do with <b>quick walk-through calling</b>. Come enjoy the camaraderie, physical and mental stimuli, and the glorious music.

<p>(If you have friends to whom you would like to introduce the joys of English Country Dancing, please bring them on the second and fourth 
Thursdays to the dances in <a href="/series/english/berkeley_wed/">Berkeley</a>, or to the <a href="/series/english/san_francisco/">San Francisco<a>, <a href="/series/english/palo_alto">Palo Alto</a>, <a href="/series/english/peninsula/">Peninsula</a> or <a href="/series/english/san_jose/">South Bay</a> dances. Check the listings on the quarterly BACDS calendar flyer or on the calendar at www.bacds.org)
</p>
EOL
        },
        {
            name => 'San Francisco Saturday English Dance',
            series_xid => 'SF-ENGLISH',
            frequency => 'second Saturday',
            series_url => 'https://bacds.org/series/english/san_francisco/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./english/san_francisco/content.html:
<a target="_blank" href="http://www.facebook.com/group.php?gid=196323749310">
<img border="0" src="/images/FindUsOnFacebook.gif" width="175" height="50"
  alt="Find us on Facebook"></a><br><br>
<a target="_blank" href="http://www.secondsaturdayenglish.com">
<img border="0" src="/images/blog.jpg" width="75" height="75"
  alt="Follow our Blog"></a><br>
<br> 
<!--#include virtual="/series/shared/location_spc.html" -->
<!--#include virtual="/series/shared/time_special_spc.html" -->
<!--#include virtual="/series/shared/price_weekend.html" -->
<!--#include virtual="/series/shared/directions_spc.html" -->
EOL
            display_text => <<'EOL',
<div class="center">
<h2 class="dance">Second Saturday -- St. John&#39;s Presbyterian Church</h2>
</div>
EOL
        },
        {
            name => 'San Jose English',
            series_xid => 'SJ-ENGLISH',
            frequency => 'second Sunday afternoons of the month, September through June',
            series_url => 'https://bacds.org/series/english/san_jose/',
            is_deleted => 0,
            sidebar => <<'EOL', # ./english/san_jose/content.html:
<em>Regular Location</em><br />
<!--#include virtual="/series/shared/location_fsj.html" -->
<!--#include virtual="/series/shared/time_aft_150_3.html" -->
<!--#include virtual="/series/shared/price_weekend.html" -->
<!--#include virtual="/series/shared/directions_fsj.html" -->
EOL
            display_text => <<'EOL',
<div class="center">
<h2 class+"dance">September - June, 2nd Sundays <br /></h2>
</div>
EOL
        },
        {
            name => 'Atherton Woodshed',
            series_xid => 'ATH-WOODSHED',
            frequency => 'second Tuesday',
            is_deleted => 0,
            sidebar => <<'EOL', # ./woodshed/atherton/content.html:
<!--#include virtual="/series/shared/location_hpp.html" -->
<!--#include virtual="/series/shared/time_late_120.html" -->
<!--#include virtual="/series/shared/price_woodshed.html" -->
<!--#include virtual="/series/shared/directions_hpp.html" -->
EOL
            display_text => <<'EOL',
<h1 class="dance">Palo Alto second-Monday Woodshed dance</h1>
EOL
        },
        {
            name => 'English Ceilidh',
            series_xid => 'ENGLISH-CEILIDH',
            frequency => 'occasional',
            is_deleted => 0,
            sidebar => <<'EOL', # ./ceilidh/oakland/content.html:
<!--#include virtual="/series/shared/location_hum.html" -->
<!--#include virtual="/series/shared/time_mid.html" -->
<!--#include virtual="/series/shared/price_weekend.html" -->
<!--#include virtual="/series/shared/directions_hum.html" -->
EOL
            display_text => <<'EOL',
<h1 class="dance">Oakland (formerly Berkeley) English Ceilidh</h1>
<p align=justify>
English ceilidh ("kay-lee") dances, which you can call barn dances if you
can't pronounce ceilidh, are raucous social dances similar to those found at
pubs throughout England. Different in both style and music from both
Scottish and Irish ceilidhs, English ceilidhs combine traditional English
music performed by amplified ensembles with dances that are derived from but
(usually) simpler English country dances. These are entry-level dances,
extremely welcoming to groups of first-timers, children old enough to dance
apart from their parents, and even morris dancers. Our English ceilidh
dances are held occasionally, usually at Humanist Hall in Oakland.
<p>
EOL
        },
        {
            name => 'Odd Sundays Online',
            series_xid => 'ODD-SUNDAYS-ONLINE',
            frequency => 'odd-numbered Sundays',
            is_deleted => 0,

            series_url => 'https://bacds.org/series/virtual/oddsundays.html',
            sidebar => <<'EOL',
<b>NOTE:</b> as of November 2021, this series has moved to the <b>even</b>
Sundays of the month, and is now the <i>Oddly Even Sunday English Dance
Party</i>. Doors open 1:00 pm PDT (sound check and chat), dance starts at
1:30PM PDT. Link will appear the Thursday or Friday before the dance on
bacds-announce mailing list
(subscribe <a href=https://www.bacds.org/mailman/listinfo/bacds-announce>here</a>)
and on the Odd Sundays mailchimp list (to learn how to join that Odd Sundays
email list, email Sharon at <script src="https://bacds.org/javascript/sg-addr.js"></script>).
            </p>
EOL
            display_text => <<'EOL',
<a href="#oddsundays"></a>
<h2>Odd Sundays English Dance Party</b> in the cloud!</h2>
<p>
The <b>Odd Sundays Dance</b> features either Sharon Green or Kalia Kliban
calling solo adaptations of English country dances either to recorded or live
music.
<!--
<p>
<b>NOTE:</b> beginning in September, this series moves to the <b>even</b>
Sundays of the month, when it will become the <i>Even Odder Sundays English
Dance Party</i>.
-->
<p>
500 persons max.
<p>
We are still learning how to run dances on Zoom. There will be glitches. Bring
your patience, sense of humor, and love of ECD.
<p>
Before the meeting, clear a safe, spacious (to some degree of spacious) area in
which you can dance. Put on your dance shoes.
<p>
When you join, please  keep your mic muted, except when you speak, and then
re-mute immediately. (Computer users: If you mute your mic  yourself, you can
quickly unmute yourself by pressing the space bar. Hold it down while you
speak. When you release the space bar, that automatically will re-mute you.)
<p>
Click on Participants at the bottom of your screen to see who else is online.
Click on Chat to follow conversations or to write comments.
<p>
Please raise your hands (use the icon, if you have that option) to signal that
you want to speak. If we continue to have a large number of dancers, it will be
hard to spot the raised hands. Forgive us if we miss your signal.
<p>
<b>Doors open 1:00 pm PDT (sound check and chat), dance starts at 1:30PM PDT.
</b> The Zoom invitation will <b>not</b> be posted online; it will be shared
via the <a href="https://www.bacds.org/email/?l=bacds-announce:">BACDS-announce</a>
email list a couple of days before the event and on the Odd Sundays mailchimp
list (to learn how to join that Odd Sundays email list, email Sharon at
<script src="https://bacds.org/javascript/sg-addr.js"></script>).
<p>
Sharon or Kalia will post the tentative dance &amp; set list a few days before the event.
<p>
EOL
        },
        {
            name => 'Online Concerts',
            series_xid => 'ONLINE-CONCERTS',
            frequency => 'occasional',
            is_deleted => 0,
        },
        {
            name => 'Hey Days English Week',
            series_xid => 'HEYDAYS',
            frequency => 'annual',
            is_deleted => 0,
        },
        {
            name => 'Family Week',
            series_xid => 'FAMWK',
            frequency => 'annual',
            is_deleted => 0,
        },
        {
            name => 'Balance the Bay',
            series_xid => 'BTB',
            frequency => 'annual',
            is_deleted => 0,
        },
        {
            name => 'English Regency',
            series_xid => 'ENGLISH-REGENCY',
            frequency => 'second Fridays',
            series_url => 'https://bacds.org/series/english/palo_alto_reg/',
            is_deleted => 0,
            sidebar => <<'EOL',
Regular Location:
<!--#include virtual="/series/shared/location_sme.html" -->
<!--#include virtual="time.html" -->
<!--#include virtual="price.html" -->
EOL
            display_text => <<'EOL',
<p>
BACDS and <a href="http://baers.org">The Bay Area English Regency Society (BAERS) </a> co-sponsor second Friday Regency dance parties.  Strictly speaking, the Regency is the period from 1811-1820 when George III was too sick to rule and Parliament authorized his wastrel son (later George IV) as Prince Regent.  This is the era of the Napoleonic Wars, the Romantic poets, composers like Beethoven, and the years when the novels of Jane Austen were published.  These focus on accessible dances with some connection to Jane Austen's lifetime (1778 - 1816), extending to the end of the Regency (1820), sometimes using American dances of the same period, which allows for longways (duple and triple) minors, three and four couple sets, and we'll do two-couple dances (which are out of period) if that's how many people are there at the start, so we will start on time.   We dance in the spirit of the Regency era, but usually in modern Englsh style.  Because the waltz becomes popular in England in our period, we usually have waltz country dances and several free waltzes, and occasionally some choreographed waltz couple dances.  The famous "Congress of Vienna" dance was invented for Regency dancing.  This is an excellent series for new dancers and people wanting to acquire fluency in country dance.  These second-Friday dance parties are casual-dress events.  BAERS also sponsors several balls a year with historical themes (see BAERS website, above) where we encourage historical, formal, or festive dress but don't require it.
<p>
Alan Winston is the series programmer and the most frequent leader for the dance parties, but other callers who share with Alan both an interest in the period and skill in teaching beginners sometimes share the evening or take the whole evening.  On rare occasions we repurpose the second-Friday evening to take advantage of visiting world-class talent, so our second-Friday dance parties have been called by Andrew Shaw, Graham Christian, and others.
</p>
<p>
The house band, Divertimento, is usually led by BAERS Music Director James Langdell, with William Allen on piano, Paul Kostka on whistles and other instruments, Jeannette Langdell on violin, Bill Langdell on horns, and welcomes sit-ins from strong players who can sight-read.  Band and caller are all acoustic.
<p>
The entrance to the St. Mark's compound (sanctuary, social hall, and rectory) is fairly inconspicuous, on the South side of Colorado, mid-block, about a block and half West of Middlefield Road in mid-town, far from the train station but close to a bus route.  There's a very big parking lot which isn't visible from the street.  The dance is usually in the Social Hall (good acoustics and lighting, excellent floor), but is occasionally displaced into the Sanctuary (fantastic acoustics, dramatic lighting, linoleum-over-wood floor), usually in May when the St. Mark's takes a turn in the Hotel de Zink rotation.
</p>
EOL
        },
    );

    foreach my $series (@series) {
        my $new = $dbh->resultset('Series')->new({});

        say "doing series $series->{name}";

        $new->$_( $series->{$_} ) for qw/
            name
            series_xid
            frequency
            series_url
            sidebar
            display_text
        /;
        $new->is_deleted(0);

        $new->insert;
    }
}


sub setup_event_templates {
    my ($dbh) = @_;

    my @templates = (
        {
            series_name => "Berkeley Contra",
            start_time =>'19:30',
            style =>  'CONTRA',
            venue =>  'CCB',
            parent_org => 'BACDS',
            is_template => 1,
        },
        {
            series_name => "Berkeley English",
            start_time =>'19:30',
            style =>  'ENGLISH',
            venue =>  'CCB',
            parent_org => 'BACDS',
            is_template => 1,
        },
        {
            series_name => "Berkeley Fourth Saturday Experienced Dance",
            start_time =>'19:30',
            style =>  'ENGLISH',
            venue =>  'CCB',
            parent_org => 'BACDS',
            is_template => 1,
        },
        {
            series_name => "San Francisco Saturday English Dance",
            start_time =>'19:30',
            style =>  'ENGLISH',
            venue =>  'SJP',
            parent_org => 'BACDS',
            is_template => 1,
        },
    );

    foreach my $template (@templates) {

        my $event = $dbh->resultset('Event')->new({});
        $event->is_deleted(0);
        $event->is_template(1);
        $event->start_time($template->{start_time});
        $event->insert;

        my $rs;

        $rs = $dbh->resultset('Series')->search({
            name => $template->{series_name}
        });
        my $series = $rs->single or die "can't find series for $template->{series_name}";
        $event->series_id($series->id);
        $event->update;

        $rs = $dbh->resultset('Style')->search({
            name => $template->{style}
        });
        my $style = $rs->single or die "can't find style for $template->{style}";
        $event->add_to_styles($style, {
            ordering => 1,
        });

        $rs = $dbh->resultset('Venue')->search({
            vkey => $template->{venue}
        });
        my $venue = $rs->single or die "can't find venue for $template->{venue}";
        $event->add_to_venues($venue, {
            ordering => 1,
        });

        $rs = $dbh->resultset('ParentOrg')->search({
           abbreviation  => $template->{parent_org}
        });
        my $parent_org = $rs->single or die "can't find parent_org for $template->{parent_org}";
        $event->add_to_parent_orgs($parent_org, {
            ordering => 1,
        });
    }
}
