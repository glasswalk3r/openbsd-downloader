package App::OpenBSD::Downloader::Progress;

use strict;
use warnings;
use Carp qw(confess);
use Term::ProgressBar;
use Hash::Util qw(lock_keys);

use App::OpenBSD::Downloader::Events ':all_events';

# VERSION
our $DEFAULT_INTERVAL = 3;

sub new {
    my ( $class, $notifier, $update_interval ) = @_;
    my $self = {
        total_size         => 0,
        current_size       => 0,
        formatted_size     => undef,
        received_bytes     => 0,
        start_time         => 0,
        last_callback_time => 0,
        file_url           => undef,
        progress           => undef,
        interval           => $update_interval || $DEFAULT_INTERVAL
    };

    bless $self, $class;
    return lock_keys( %{$self} );
}

sub _start {
    my ( $self, $event_data ) = @_;
    my $event = START;

    my @wanted = qw(total_size start_time file_url);

    foreach my $key (@wanted) {
        confess "No such '$key' in the '$event' received"
            unless ( exists( $event_data->{$key} ) );
        $self->{$key} = $event_data->{$key};
    }
    $self->_format_bytes;
    $self->{progress} = Term::ProgressBar->new(
        {
            name  => 'Image',
            count => $self->{total_size},
            ETA   => 'linear'
        }
    );
}

sub _progress {
    my ( $self, $event_data ) = @_;
    my $event  = PROGRESS;
    my $wanted = 'chunck_size';
    confess "Missing '$wanted' in event '$event'"
        unless ( exists( $event_data->{$wanted} ) );
    $self->{current_size} += $event_data->{wanted};

    my $spent_time = time - $self->{start_time};

    if ( $spent_time != $self->{last_callback_time} ) {
        $self->{last_callback_time} = $spent_time;
        $self->_show;
    }

}

sub notify {
    my ( $self, $event, $event_data ) = @_;

CASE: {
        if ( $event == START ) {
            $self->_start($event_data);
            last CASE;
        }

        if ( $event == PROGRESS ) {
            $self->progress($event_data);
            last CASE;
        }

        if ( $event == FINISH ) {
            $self->_force_update;
            $self->_show;
            last CASE;
        }
        else {
            confess "Unknown event '$event'";
        }

    }

}

sub _force_update {
    my $self = shift;
    $self->{current_size} = $self->{total_size};
}

sub _show {
    my ($self) = @_;
    my $perc_completed = $self->{current_size} / $self->{total_size};

    if ( $self->{last_callback_time} > $self->{interval} ) {
        $self->{speed} = $self->_update_speed();
    }

    $self->{progress}->message(
        sprintf 'Downloaded %d of %s at %s', ( $perc_completed * 100 ),
        $self->{formatted_size}, $self->{speed}
    );

    $self->{progress}->update( $self->{current_size} );
}

sub _update_speed {
    my $self  = shift;
    my $value = int( $self->{current_size} / $self->{last_callback_time} );
    $self->{speed} = $self->_format_bytes() . '/sec';
}

sub _format_bytes {
    my $self = shift;
    my $n    = int( $self->{total_size} );

    if ( $n >= 1024 * 1024 ) {
        $self->{formatted_size} = sprintf '%.3g MB', $n / ( 1024.0 * 1024 );
        return 1;
    }

    if ( $n >= 1024 ) {
        $self->{formatted_size} = sprintf '%.3g KB', $n / 1024.0;
        return 1;
    }

    $self->{formatted_size} = "$n bytes";
    return 1;
}

1;

# -*- mode: perl -*-
# vi: set ft=perl :
