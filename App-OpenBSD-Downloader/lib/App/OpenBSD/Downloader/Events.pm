package App::OpenBSD::Downloader::Events;

use warnings;
use strict;
use base 'Exporter';

# VERSION

use constant START    => 1;
use constant PROGRESS => 2;
use constant FINISH   => 3;

our @EXPORT_OK   = ( 'START', 'PROGRESS', 'FINISH' );
our %EXPORT_TAGS = ( 'all_events' => \@EXPORT_OK );

1;

# -*- mode: perl -*-
# vi: set ft=perl :
