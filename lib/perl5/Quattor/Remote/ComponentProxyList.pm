#
# Quattor::Remote::ComponentProxyList class
#
# Copyright (C) 2009  Contributor
#

package Quattor::Remote::ComponentProxyList;

use strict;
our (@ISA, $this_app);
use CAF::ReporterMany;
use LC::Exception qw (SUCCESS throw_error);
use CAF::Object;
use Quattor::Remote::ComponentProxy;

*this_app = \$main::this_app;

@ISA = qw (CAF::Object CAF::Reporter);
my $ec = LC::Exception::Context->new->will_store_errors;

=pod

=head1 NAME

Quattor::Remote::ComponentProxyList - component proxy list class

=head1 SYNOPSIS

=head1 INHERITANCE

    CAF::Object, CAF::Reporter
    
=head1 DESCRIPTION

Instantiation, execution and management of ComponentProxy object instances.

=over

=back

=head1 AUTHOR

Ben Jones <Ben.Jones@morganstanley.com>

=cut

#------------------------------------------------------------------------------
#           Public Methods/Functions
#------------------------------------------------------------------------------

=pod

=head2 Public Methods

=over 4

=cut

sub executeConfigComponents {
	my ($self) = @_;
	
	$self->info("Executing configure on components...");
	$self->report();
	
	my %err_comps_list;
	my %warn_comps_list;
	my %global_status = (
	                       'ERRORS'    => 0,
	                       'WARNINGS'  => 0,
	                    );
	                    
	my $sortedList = $self->_sortComponents($self->{'CLIST'});
	if (defined $sortedList) {
		# execute all the components
		
		my $OK   = 1;
		my $FAIL = 2;
		my %exec_status = map { $_->name(), 0 } @{$sortedList};
		
		foreach my $comp (@{$sortedList}) {
			$self->report();
			$self->info("Running component: " . $comp->name() . " on node " . $self->{NODE});
			$self->report('------------------------------------------------------------------');
			my @broken_dep = ();
			foreach my $predep (@{$comp->getPreDependencies()}) {
				if ((!$this_app->option('nodeps')) && ($exec_status{$predep} != $OK)) {
					push (@broken_dep, $predep);
					$self->debug(1, "Predependencies broken for component " . $comp->name() . " on node " . $self->{NODE} . ": " . $predep);
				}
			}
			if (scalar @broken_dep) {
			    my $err = "Cannot run component: " . $comp->name() . " on node " . $self->{NODE} . 
				" as pre-dependencies failed: " . join(',', @broken_dep);
			    $self->error($err);
			    $global_status{ERRORS}++;
			    $err_comps_list{$comp->name()} = 1;
			    $self->set_state($comp->name(), $err);
			} else {
				# we set the state to "unknown" (in effect) just before we run configure
				# so that the state will reflect that this component has still not run
				# to completion. All code-paths following this MUST either set_state or
				# clear_state.
				$self->set_state($comp->name(), "");
				
				my $ret = $comp->executeConfigure();
				if (not defined $ret) {
					my $err = "cannot execute configure on component " . $comp->name();
					$self->error($err);
					$global_status{'ERRORS'}++;
					$err_comps_list{$comp->name()} = $FAIL;
					$exec_status{$comp->name()} = $FAIL;
					$self->set_state($comp->name(), $err);
				} else {
					if ($ret->{'ERRORS'}) {
						$err_comps_list{$comp->name()} = $ret->{'ERRORS'};
						$exec_status{$comp->name()} = $FAIL;
						$self->set_state($comp->name(), $ret->{'ERRORS'});
					} else {
						$exec_status{$comp->name()} = $OK;
						$self->clear_state($comp->name());
					}
					if ($ret->{'WARNINGS'}) {
						$warn_comps_list{$comp->name()} = $ret->{'WARNINGS'};
					}
					$global_status{'ERRORS'} += $ret->{'ERRORS'};
					$global_status{'WARNINGS'} += $ret->{'WARNINGS'};
				}
			}
		}
		
	} else {
		$self->error("Cannot sort components according to dependencies");
		$global_status{ERRORS}++;
	}
	
	$global_status{'ERR_COMPS'} = \%err_comps_list;
	$global_status{'WARN_COMPS'} = \%warn_comps_list;
	
	return \%global_status;
}

sub executeUnconfigComponent {
	my ($self) = @_;
	
	my $comp = @{$self->{'CLIST'}}[0]; # FIXME only one comp? Cmdline maybe, but not for a list.
	
	my %global_status = (
	                       'ERRORS'   => 0,
	                       'WARNINGS' => 0 
	                    );
	for my $comp (@{$self->{'CLIST'}}) {                    
	   if (defined $comp) {
		  my $ret = $comp->executeUnconfigure();
		  if (defined $ret) {
			 $self->report('unconfigure on component ' . $comp->name() . ' executed, ' .
			         $ret->{'ERRORS'} . ' errors, ' .
			         $ret->{'WARNINGS'} . ' warnings');
			 $global_status{'ERRORS'}   += $ret->{'ERRORS'};
			 $global_status{'WARNINGS'} += $ret->{'WARNINGS'};
		  } else {
			 $self->error('cannot execute unconfigure on component ' . $comp->name());
			 $global_status{'ERRORS'}++;
		  }
	   } else {
		  $self->error('could not instantiate component ' . $comp->name());
		  $global_status{'ERRORS'}++;
	   }
	}
	return \%global_status;
}

=pod 

=item set_state($component, $message)

Mark a component as failed within our state directory

=cut

sub set_state {
	my ($self, $comp, $msg) = @_;
	if ($this_app->option('state')) {
		my $dir = $this_app->option('state') . "/" . $self->{NODE};
		if (! -d $dir) {
			if (not mkdir($dir)) {
				$self->warn("Failed to create state dir $dir: $!");
				return undef;
			}
		}
		my $file = $dir . "/" . $comp;
		if (open(TOUCH), ">$file") {
			print TOUCH "$msg\n";
			close(TOUCH);
		} else {
			$self->warn("Failed to write state file $file: $!");
		}
	}
}

=pod 

=item clear_state($comp)

Mark a component as succeeded within our state directory

=cut

sub clear_state {
	my ($self, $comp) = @_;
	if ($this_app->option('state')) {
		my $file = $this_app->option('state') . "/" . $self->{NODE} . "/" . $comp;
		if (-f $file) {
			unlink($file) or $self->warn("Failed to clean state file $file: $!");
		}
	}
}

=pod

=back

=head2 Private Methods

=item _initialize($node, $config, @components)

object initialization (done via new)

=cut

sub _initialize {
	my ($self, $node, $config, $connection, @components) = @_;
	$self->{'CCM_CONFIG'} = $config;
	$self->{'NODE'} = $node;
	$self->{'CONNECTION'} = $connection;
	$self->{'NAMES'} = \@components;
	
	return $self->_getComponents();
}

sub _getComponents {
	my ($self) = @_;
	
	my @compnames = @{$self->{'NAMES'}};
	my @all = grep { /^all$/ } @compnames;
	if (@all) {
		@compnames = (); # empty the compnames, all means all, so we grab them from config
	}
	
	if (scalar(@compnames) <= 0) {
		# either we've had 'all' specified, or nothing at all - which amounts to the same thing
		my $res = $self->{'CCM_CONFIG'}->getElement('/software/components');
		if (not defined $res) {
			$ec->ignore_error();
			$self->error("No components found in profile for $self->{'NODE'}");
			return undef;
		}
		my %els = $res->getHash();
		foreach my $cname (keys %els) {
			my $prop = $self->{'CCM_CONFIG'}->getElement('/software/components/' . $cname . '/active');
			if (not defined $prop) {
				$ec->ignore_error();
				$self->warn('component ' . $cname .
				    " 'active' flag not found in node profile under /software/components/" . $cname . "/, skipping");
				next;
			} else {
				if ($prop->getBooleanValue() eq 'true') {
					push (@compnames, $cname);
				}
			}
		}
		$self->verbose("active components found in profile for $self->{'NODE'}: ");
		$self->verbose('  '.join(',', @compnames));
	}
	
	if (scalar(@compnames) <= 0) {
		# this time if we don't have components, it's a problem
		$self->error("No active components found in profile for $self->{'NODE'}"); # XXX should this be an error?
		return undef;
	}
	
	# XXX skip would be here if we had a skip option
	# ie:
	# @compnames = grep ($_ ne $self->{'SKIP'}, @compnames)
	# ...but we haven't implemented skip, so...
	
	my @comp_proxylist = ();
    foreach my $cname (@compnames) {
    	my $comp_proxy = Quattor::Remote::ComponentProxy->new($cname, $self->{'CCM_CONFIG'}, $self->{'NODE'}, $self->{'CONNECTION'});
    	if (defined $comp_proxy) {
    		push (@comp_proxylist, $comp_proxy);
    		my @pre = @{$comp_proxy->getPreDependencies()};
    		my @post = @{$comp_proxy->getPostDependencies()};
    		foreach my $pp (@pre, @post) {
    			if ($this_app->option('autodeps') eq 'yes') {
    				push @compnames, $pp;
    				$self->info("adding missing pre/post requisite component: $pp");
    			}
    		}
    	} else {
    		$ec->ignore_error();
    		if (not $this_app->option('allowbrokencomps')) {
                $self->error('cannot instantiate component: ' . $cname);
                return undef;
            } else {
            	$self->warn('ignoring broken component: ' . $cname);
            }
    	}
    }
    $self->{'CLIST'} = \@comp_proxylist;
    return SUCCESS;
}

#
# sort the components according to the dependencies
#
sub _sortComponents {
	my ($self, $unsortedCompProxyList) = @_;
	
	$self->verbose("Sorting components for node $self->{NODE} according to dependencies...");
	
	my %comps;
	%comps = map {$_->name(), $_} @$unsortedCompProxyList;
	my $after = {};
	my $prev = undef;
	foreach my $comp (@$unsortedCompProxyList) {
		my $name = $comp->name(); # XXX erm, isn't this just $comps{$comp} ?
		$after->{$name} ||= {};
		my @pre = @{$comp->getPreDependencies()};
		my @post = @{$comp->getPostDependencies()};
		if (scalar(@pre) or scalar(@post)) {
			foreach (@pre) {
				if (defined $comps{$_}) {
					$after->{$_}->{$name} = 1;
				} else {
					if (not $this_app->option('nodeps')) {
						$self->error("pre-requisite for component \"$name\" on node \"$self->{NODE}\" does not exist: $_");
						return undef;
					}
				}
			}
			foreach (@post) {
				if (not defined $comps{$_}) {
					if (not $this_app->option('nodeps')) {
                        $self->error("Pre-requisite for component \"$name\" on node \"$self->{NODE}\" does not exist: $_");
                        return undef;
                    }
                    $self->error("Post-requisite for component \"$name\" on node \"$self->{NODE}\" does not exist: $_");
                    return undef;
				}
				$after->{$name}->{$_} = 1;
			}
		} else {
			$prev = $name;
		}
	}
	my $visited = {};
	my $sorted = [()];
	foreach my $c (sort keys (%$after)) {
		if (not $self->_topoSort($c, $after, $visited, {}, $sorted, 1)) {
			$self->error("Cannot sort dependencies");
			return undef;
		}
	}
	my @sortedcompProxyList = map { $comps{$_} } @$sorted;
	return \@sortedcompProxyList;
}

# topological Sort
# preliminary mkxprof based version, to be replaced by a
# qsort call in the next alpha release.
#
sub _topoSort {
	# Topological sort (Aho, Hopcroft & Ullman)
	
	my $self=shift;
    my $v = shift;         # Current vertex
    my $after = shift;     # Hash of component followers
    my $visited = shift;   # Visited markers
    my $active = shift;    # Components on this path (to check for loops)
    my $stack = shift;     # Output stack
    my $depth = shift;     # Depth
    
    return SUCCESS if ($visited->{$v});
    $visited->{$v} = $active->{$v} = $depth;
    foreach my $n (keys(%{$after->{$v}})) {
        if ($active->{$n}) {
            my @loop = sort { $active->{$a} <=> $active->{$b} } keys(%$active);
            $self->error("dependency ordering loop detected: ",
            join(' < ',(@loop,$n)));
            return undef;
        }
        return undef unless ($self->_topoSort($n,$after,$visited,$active,$stack,$depth+1));
    }
    delete $active->{$v}; 
    unshift @$stack,($v);
    return SUCCESS;
}

