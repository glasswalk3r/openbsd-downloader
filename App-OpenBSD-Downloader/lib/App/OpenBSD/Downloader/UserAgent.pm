package App::OpenBSD::Downloader::UserAgent;

use warnings;
use strict;
use Carp qw(confess);
use LWP::UserAgent;
use App::OpenBSD::Downloader::Events ':all_events';
use Hash::Util qw(lock_keys);

# based on https://metacpan.org/dist/libwww-perl/source/bin/lwp-download

# VERSION
our $VERSION;
our $FAILURE_EVENT = 'X-Died';

sub new {
    my ( $class, $notifier ) = @_;
    my $self = {
        ua => LWP::UserAgent->new(
            agent      => "OpenBSD (Perl) Downloader/$VERSION",
            keep_alive => 1,
            env_proxy  => 1,
        ),
        notifier    => $notifier,
        in_progress => 0
    };

    bless $self, $class;
    return lock_keys(%{$self});
}

sub get_image {
    my ( $self, $cfg ) = @_;
    my $file = $cfg->filename();
    my $out;

    if ( -f $file ) {
        print "image $file is already available, won't overwrite it\n";
    }
    else {
        my $res = $self->{ua}->request(
            HTTP::Request->new( GET => $cfg->image_url() ),
            sub {
                my ( $data_chunk, $response ) = @_;

                unless ( $self->{in_progress} ) {
                    open( $out, '>', $file )
                        or confess "Cannot write to $file: $!";
                    binmode($out);
                    $self->{notifier}->notify(
                        START,
                        (
                            {
                                total_size => $response->content_length,
                                start_time => time(),
                                file_url   => $cfg->image_url()
                            }
                        )
                    );
                    $self->{in_progress} = 1;
                }

                print $out $data_chunk
                    or confess "Can't write to $file: $!\n";

                $self->{notifier}->notify(
                    PROGRESS,
                    (
                        {
                            chunk_size => length($data_chunk)
                        }
                    )
                );

            }
        );

        _clean_on_error( $out, $res->header($FAILURE_EVENT), $file )
            if ( $res->header($FAILURE_EVENT) );

        _clean_on_error( $out, $res->status_line, $file )
            unless ( $res->is_success );

        $self->{notifier}->notify(FINISH);

        close($out) or confess "Can't write to $file: $!";
    }
}

sub _clean_on_error {
    my ( $out, $error, $file ) = @_;
    close($out)  or confess "Can't write to $file: $!";
    unlink $file or warn "Cannot remove $file due failure in downloading: $!";
    confess $error;
}

sub get_sha_signature {
    my ( $self, $cfg ) = @_;
    my $response = $self->{ua}->get( $cfg->sha_signature_url(),
        ':content_file' => $cfg->sha_signature() );

    if ( $response->is_success ) {
        print "Signature downloaded successfully\n";
    }
    else {
        confess "Failed to downlod SHA256 signature: "
            . $response->status_line;
    }

    $response
        = $self->{ua}
        ->get( $cfg->pgp_key_url(), ':content_file' => $cfg->pgp_key() );

    if ( $response->is_success ) {
        print "Public PGP key downloaded successfully\n";
    }
    else {
        confess "Failed to downlod the public PGP key: "
            . $response->status_line;
    }
}

1;

# -*- mode: perl -*-
# vi: set ft=perl :
