#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";


# use this block if you don't need middleware, and only have a single target Dancer app to run here
use bacds::Scheduler;

bacds::Scheduler->to_app;

=begin comment
# use this block if you want to include middleware such as Plack::Middleware::Deflater

use bacds::Scheduler;
use Plack::Builder;

builder {
    enable 'Deflater';
    bacds::Scheduler->to_app;
}

=end comment

=cut

=begin comment
# use this block if you want to mount several applications on different path

use bacds::Scheduler;
use bacds::Scheduler_admin;

use Plack::Builder;

builder {
    mount '/'      => bacds::Scheduler->to_app;
    mount '/admin'      => bacds::Scheduler_admin->to_app;
}

=end comment

=cut

