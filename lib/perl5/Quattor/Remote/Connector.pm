#
# Quattor::Remote::ComponentProxy
#
# Copyright (C) 2009  Contributor
#

package Quattor::Remote::Connector;

use strict;
our(@ISA, $this_app);
use CAF::ReporterMany;
use CAF::Object;
use CAF::Log;

*this_app = \$main::this_app;

@ISA = qw(CAF::Object CAF::ReporterMany);

=pod

=head1 NAME

Quattor::Remote::Connector - connection pool class

=head1 SYNOPSIS

=head1 INHERITENCE

    CAF::Object, CAF::ReporterMany
    
=head1 DESCRIPTION

Create and manage connections to remote devices in need of configuration.

=over

=back

=head1 AUTHOR

Ben Jones <Ben.Jones@morganstanley.com>

=cut

=pod

=head2 Private methods

=item _initialize($node, $cfg, $connector, $proxy)

node is the node to be configured
config is the ccm config for the node
connector is a module that provides the device specific connection details
proxy (if set) is where a connection will be made to rather than the host (ie vmware vc)

=cut

sub _initialize {
    my ($self) = @_;
    $self->debug(5, "Initialized Quattor::Remote::Connector");
}

=pod

=head2 Public methods#

=item connect()

returns connection object

=cut

sub connect {
    my ($self, $node, $cfg, $connector, $proxy) = @_;
    # allow for namespaced nodes.
    my $context = "node";
    if ($node =~ m{^(.*)/([^/]+)$}) {
	$context = $1;
	$node = $2;
    }
    $proxy ||= $node;
    eval ( "use $connector" );
    if ($@) {
        $self->error("Couldn't load $connector: $@");
        return undef;
    }
    $self->debug(4, "Instantiating $connector");
    $self->{module} = $connector->new();
    my $connection = $self->{module}->connect($node, $proxy);
    my $method = $context . "_context";
    return $self->{module}->$method($node, $connection->session(), $cfg, $proxy);
}

sub disconnect {
    my ($self) = @_;
    $self->{module}->disconnect();
}

1;
