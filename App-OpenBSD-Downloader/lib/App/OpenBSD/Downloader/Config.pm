package App::OpenBSD::Downloader::Config;

use strict;
use warnings;
use Carp qw(confess);

sub new {
    my ( $class, $params_ref ) = @_;
    my $self = {
        image_name    => 'install',
        dir_tree      => '/pub/OpenBSD/',
        sha_signature => 'SHA256.sig'
    };
    bless $self, $class;
    $self->_validate_params($params_ref);

    foreach my $param (qw(mirror major minor arch)) {
        $self->{$param} = $params_ref->{$param};
    }

    if ( $params_ref->{type} eq 'disk' ) {
        $self->{image_extension} = 'img';
    }
    else {
        $self->{image_extension} = 'iso';
    }

    return $self;
}

sub _validate_params {
    my ( $self, $params_ref ) = @_;
    confess 'parameters must be a hash reference'
        unless ( ref($params_ref) eq 'HASH' );
    my @required_params = qw(mirror major minor type arch);

    foreach my $param (@required_params) {
        confess "'$param' is a required parameter"
            unless ( exists( $params_ref->{$param} ) );
    }

    confess 'mirror must be an URL, not "' . $params_ref->{mirror} . '"'
        unless ( defined( $params_ref->{mirror} )
        and ( $params_ref->{mirror} ne '' ) );

    foreach my $version (qw(major minor)) {
        confess "'$version' must be an integer"
            unless ( defined( $params_ref->{major} )
            and ( $params_ref->{major} =~ /^\d+$/ ) );
    }

    confess 'type parameter must be equal "iso" or "disk"'
        unless (
        defined( $params_ref->{type} )
        and (  ( $params_ref->{type} eq 'iso' )
            or ( $params_ref->{type} eq 'disk' ) )
        );

    # TODO: add other architectures
    confess 'arch parameter must be "amd64" or "i386"'
        unless (
        defined( $params_ref->{arch} )
        and (  ( $params_ref->{arch} eq 'amd64' )
            or ( $params_ref->{arch} eq 'i386' ) )
        );

}

sub sha_signature {
    my $self = shift;
    return $self->{sha_signature};
}

sub version {
    my $self = shift;
    return $self->{major} . '.' . $self->{minor};
}

sub filename {
    my $self = shift;
    return
          $self->{image_name}
        . $self->{major}
        . $self->{minor}
        . $self->{image_extension};
}

sub pgp_key {
    my $self = shift;
    return 'openbsd-' . $self->{major} . $self->{minor} . '-base.pub';
}

# https://ftp.openbsd.org/pub/OpenBSD/7.1/openbsd-71-base.pub
sub pgp_key_url {
    my $self = shift;
    return
          $self->{mirror}
        . $self->{dir_tree}
        . $self->version() . '/'
        . $self->pgp_key();
}

# https://openbsd.c3sl.ufpr.br/pub/OpenBSD/7.1/amd64/SHA256.sig
sub sha_signature_url {
    my $self = shift;
    return
          $self->{mirror}
        . $self->{dir_tree}
        . $self->version()
        . $self->{arch}
        . $self->{sha_signature};
}

sub image_url {
    my $self = shift;
    return
          $self->{mirror}
        . $self->{dir_tree}
        . $self->version()
        . $self->{arch}
        . $self->filename;
}

1;

