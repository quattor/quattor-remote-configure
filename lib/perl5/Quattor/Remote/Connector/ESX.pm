#
# Quattor::Remote::ComponentProxy
#
# Copyright (C) 2009  Contributor
#

package Quattor::Remote::Connector::ESX;

use strict;
our(@ISA, $this_app);
use CAF::ReporterMany;
use LC::Exception qw(SUCCESS throw_error);

use CAF::Object;
use CAF::Log;
use VMAPI::Dependencies;
use VMAPI::Host::ESXHost;
use VMAPI::Manager::ESX::VC;

*this_app = \$main::this_app;

@ISA = qw(CAF::Object CAF::ReporterMany);

my $ec = LC::Exception::Context->new->will_store_all;

sub _initialize {
	my ($self) = @_;
	$self->debug(5, "Initialized Quattor::Remote::Connector::ESX");
}

sub connect {
	my ($self, $node, $proxy) = @_;
	$self->debug(3, "Creating ESX connection for $node with VC $proxy");
	$self->{vc} = VMAPI::Manager::ESX::VC->new(vc => $proxy);
	return $self->{vc};
}

sub disconnect {
	my ($self) = @_;
	$self->{vc}->logoff();
}

sub node_context {
	my ($self, $node, $session, $cfg, $proxy) = @_;
	my $building = $cfg->getElement("/hardware/sysloc/building")->getTree();
	$self->debug(3, "Setting session to ESX node $node");
	my $esx = VMAPI::Host::ESXHost->new(host => $node, session => $session, building => $building, vc => $proxy);
	return $esx;
}

sub clusters_context {
	my ($self, $node, $session, $cfg, $proxy) = @_;
	$self->debug(3, "Setting session to ESX cluster $node");
	my $esx = VMAPI::Host::ESX::Cluster->new($node, $session);
	return $esx;
}

1;
