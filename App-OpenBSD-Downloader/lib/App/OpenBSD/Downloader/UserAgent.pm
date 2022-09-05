package App::OpenBSD::Downloader::UserAgent;

use warnings;
use strict;
use LWP::UserAgent;

# based on https://metacpan.org/dist/libwww-perl/source/bin/lwp-download

our $VERSION = 'v1.0.0';

sub new {
    my $class = shift;
    my $self  = {
        ua => LWP::UserAgent->new(
            agent      => "OpenBSD Downloader/$VERSION",
            keep_alive => 1,
            env_proxy  => 1,
        )
    };
}

sub get_image {
    my ( $self, $cfg ) = @_;

    #    my %progress = (
    #        total_size         => 0,
    #        formatted_length   => undef,
    #        received_bytes     => 0,
    #        start_time         => 0,
    #        last_callback_time => 0,
    #    );

    my $length;          # total number of bytes to download
    my $flength;         # formatted length
    my $size     = 0;    # number of bytes received
    my $start_t  = 0;    # start time of download
    my $last_dur = 0;    # time of last callback
    my $shown    = 0;    # have we called the show() function yet

    local $| = 1;
    my $file = $cfg->filename();

    if ( -f $file ) {
        print "image $file is already available\n";
    }
    else {
        open( my $out, '>', $file ) or die "Cannot write to $file: $!";
        binmode($out);
        print $cfg->image_url(), "\n";

        my $res = $self->{ua}->request(
            HTTP::Request->new( GET => $cfg->image_url() ),
            sub {
                print $out $_[0] or die "Can't write to $file: $!\n";
                $size += length( $_[0] );

                if ( defined $length ) {
                    my $dur = time - $start_t;
                    if ( $dur != $last_dur ) {    # don't update too often
                        $last_dur = $dur;
                        my $perc = $size / $length;
                        my $speed = fbytes( $size / $dur ) . "/sec" if $dur > 3;
                        my $secs_left = fduration( $dur / $perc - $dur );
                        $perc = int( $perc * 100 );
                        my $show = "$perc% of $flength";
                        $show .= " (at $speed, $secs_left remaining)"
                            if $speed;
                        show( $show, 1 );
                    }
                }
                else {
                    show( fbytes($size) . " received" );
                }
            }
        );

        show('');
        print "\r";
        print fbytes($size);
        print " of ", fbytes($length) if defined($length) && $length != $size;
        print " received";
        my $dur = time - $start_t;

        if ($dur) {
            my $speed = fbytes( $size / $dur ) . "/sec";
            print " in ", fduration($dur), " ($speed)";
        }
        print "\n";

        if ( my $mtime = $res->last_modified ) {
            utime time, $mtime, $file;
        }

        if ( $res->header("X-Died") || !$res->is_success ) {
            if ( my $died = $res->header("X-Died") ) {
                print "$died\n";
            }
            if (-t) {
                print "Transfer aborted. Delete $file? [n] ";
                my $ans = <STDIN>;
                if ( defined($ans) && $ans =~ /^y\n/ ) {
                    unlink($file) && print "Deleted.\n";
                }
                elsif ( $length > $size ) {
                    print "Truncated file kept: ", fbytes( $length - $size ),
                        " missing\n";
                }
                else {
                    print "File kept.\n";
                }
                exit 1;
            }
            else {
                print "Transfer aborted, $file kept\n";
            }
        }

        close($out) or die "Can't write to $file: $!\n";

        # Did not manage to create any file
        print "\n" if $shown;
        if ( my $xdied = $res->header("X-Died") ) {
            print "Aborted\n$xdied\n";
        }
        else {
            # TODO: check status and print a better output
            print $res->status_line, "\n";
        }
    }
}

$SIG{INT} = sub { die "Interrupted\n"; };

#get_sha_signature( $ua, $cfg );
#verify_image($cfg);

sub get_sha_signature {
    my ( $self, $cfg ) = @_;
    my $response = $self->{ua}->get( $cfg->sha_signature_url(),
        ':content_file' => $cfg->sha_signature() );

    if ( $response->is_success ) {
        print "Signature downloaded successfully\n";
    }
    else {
        warn "Failed to downlod SHA256 signature\n";
    }

    $response
        = $self->{ua}
        ->get( $cfg->pgp_key_url(), ':content_file' => $cfg->pgp_key() );

    if ( $response->is_success ) {
        print "Public PGP key downloaded successfully\n";
    }
    else {
        warn "Failed to downlod the public PGP key\n";
    }
}

sub fbytes {
    my $n = int(shift);
    if ( $n >= 1024 * 1024 ) {
        return sprintf "%.3g MB", $n / ( 1024.0 * 1024 );
    }
    elsif ( $n >= 1024 ) {
        return sprintf "%.3g KB", $n / 1024.0;
    }
    else {
        return "$n bytes";
    }
}

sub fduration {
    use integer;
    my $secs  = int(shift);
    my $hours = $secs / ( 60 * 60 );
    $secs -= $hours * 60 * 60;
    my $mins = $secs / 60;
    $secs %= 60;
    if ($hours) {
        return "$hours hours $mins minutes";
    }
    elsif ( $mins >= 2 ) {
        return "$mins minutes";
    }
    else {
        $secs += $mins * 60;
        return "$secs seconds";
    }
}

# -*- mode: perl -*-
# vi: set ft=perl :

1;

