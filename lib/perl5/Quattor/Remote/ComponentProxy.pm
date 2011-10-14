#
# Quattor::Remote::ComponentProxy
#
# Copyright (C) 2009  Contributor
#

package Quattor::Remote::ComponentProxy;

use strict;
our (@ISA, $this_app);
use CAF::ReporterMany;
use LC::Exception qw(SUCCESS throw_error);

use Quattor;
use CAF::Object;
use EDG::WP4::CCM::CacheManager;
use EDG::WP4::CCM::Path;
use CAF::Log;
use NCM::Template; # looks like we need this for now.
use LC::Check;

use File::Path;

*this_app = \$main::this_app;

our $QRC_NAMESPACE = "Quattor::Remote::Component";

@ISA=qw(CAF::Object CAF::ReporterMany);
my $ec = LC::Exception::Context->new->will_store_errors;

use constant COMP_PREFIX => "/software/components";
use constant NAMESPACE   => "/system/components/namespace";
use constant BASEDIR     => "/var/qrc/";
use constant LIBDIR      => BASEDIR . "lib/perl/";
use constant CONFDIR     => BASEDIR . "config/";

my @_TEMPLATE_DELIMITERS = NCM::Template->GetDelimiters();

=pod 

=head1 NAME

Quattor::Remote::ComponentProxy - remote component proxy class

=head1 SYNOPSIS

=head1 INHERITANCE

    CAF::Object, CAF::Reporter
    
=head1 DESCRIPTION

Provides management functions for accesing and executing QRCs.

=over

=back

=head1 AUTHOR

Ben Jones <Ben.Jones@morganstanley.com>

=cut

=pod 

=head2 Public methods

=item getPreDependencies(): ref(@array)

Returns an array to the names of predependent components. The array is
empty if no dependencies are found.

=cut

sub getPreDependencies {
	my ($self) = @_;
	return $self->{"PRE_DEPS"};
}

=pod

=item getPostDependencies(): ref(@array)

returns a ref to an array to the names of names of postdependent components. The
array is empty if no postdependencies are found.

=cut

sub getPostDependencies {
	my ($self) = @_;
	return $self->{'POST_DEPS'};
} 

=pod

=item executeConfigure(): ref(hash)

executeConfigure loads and executes the component with 'configure'. The number of 
produced errors and warnings is returned in a hash ('ERRORS', 'WARNINGS'). If the 
component cannot be executed, undef is returned.

=cut

sub executeConfigure {
	my ($self) = @_;
	return $self->_execute('Configure');
}

=pod

=item executeUnconfigure(): ref(hash)

executeUnconfigure loads and executes the component with 'unconfigure'. The number
of produced errors and warnings is returned in a hash ('ERRORS', 'WARNINGS'). If 
the component cannot be executed, undef is returned.

=cut

sub executeUnconfigure {
	my ($self) = @_;
	return $self->_execute('Unconfigure');
}

=pod

=item name(): string

returns the name of the component

=cut

sub name {
    my $self = shift;
    return $self->{'NAME'};
}

=item dirname() : string

returns the expected directory of the perl module

=cut

sub dirname {
    my ($self) = @_;
    my $dir = $Quattor::PerlDirectory . "/" ; 
    $dir .= join("/", split(/::/, $QRC_NAMESPACE));
    $dir .= "/$self->{NAMESPACE_DIR}";
    return $dir;
}

=item filename() : string

returns the expected filename of the perl module

=cut

sub filename {
    my ($self) = @_;
    return $self->dirname() . "/" . $self->name() . ".pm";
}

=pod

=item hasFile(): boolean

returns 1 if the components perl module is installed, 0 otherwise.

=cut

sub hasFile {
    my ($self) = @_;
    return -r $self->filename();
}

=pod 

=item writeComponent(): boolean

Returns 1 if the component has the code defined in the configuration and has been 
written to disk, 0 otherwise. This will erase old component definitions if the code
is no longer defined in the XML configuration.

=cut

sub writeComponent {
	my ($self) = @_;
	
	# Pull out the component name and the configuration.
	my $cname = $self->{'NAME'};
	my $config = $self->{'CONFIG'};
	
	# ensure that both the name and configuration are defined.
	if (not defined($cname)) {
		$self->error("Internal error: component name not defined");
	}
	if (not defined($config)) {
		$self->error("Internal error: component configuration not defined");
	}
	
	# Base name for component configuration.
    my $base = "/software/components/" . $cname;
    
    # Determine if the script exists. If not, then ensure that any files
    # created previous runs are removed. This is to avoid interference
    # between old scripts and newer ones installed via a package. This is
    # needed because there is no hook for cleaning up a script if no 'Unconfigure'
    # method is defined.
    my $namespace_dir = $self->{"NAMESPACE_DIR"};
    if (not $config->elementExists($base . "/code/script")) {
    	# if the script exists, remove it.
    	my $fname = LIBDIR . $namespace_dir . "/" . $cname . ".pm";
    	if (-e $fname) {
    		unlink $fname;
    		$self->error("Error unlinking $fname: $!") if ($?);
    	}
    	
    	# Remove data directory for this template
    	my $dname = CONFDIR . $namespace_dir;
    	rmtree($dname, 0, 1) if (-e $dname);
    	return 0;
    }
    
    # Ensure that the directory for the components exists.
    my $sdir = LIBDIR . $namespace_dir;
    if (not -d $sdir) {
    	mkpath($sdir, 0, 0755);
    	if (not -d $sdir) {
    		$self->error("Cannot create directory: $sdir");
    		return 0;
    	}
    }
    
    # Ensure that the directory for the component data exists.
    # XXX do we need separate confdir etc for each node? I hope not... 
    my $ddir = CONFDIR . $namespace_dir . "/" . $cname;
    if (not -d $ddir){
    	mkpath($ddir, 0, 0755);
    	if (not -d $ddir) {
    		$self->error("Cannot create directory: $ddir");
    		return 0;
    	}
    }
    
    # Now write the script to the file.
    my $script = $config->getValue($base . '/code/script');
    my $fname = "$sdir/$cname.pm";
    unless (open(SCRIPT, "> $fname")) {
    	$self->error("Cannot write to file $fname: $!");
    	return 0;
    }
    print SCRIPT $script;
    unless (close SCRIPT) {
    	$self->error("Cannot close file $fname: $!");
    	return 0;
    }
    
    # Write out data files if specified.
    if ($config->elementExists($base . '/code/data')) {
    	my $dbhash = $config->getElement($base . "/code/data");
    	while ($dbhash->hasNextElement()) {
    		my $entry = $dbhash->getNextElement();
    		my $fname = $entry->getName();
    		my $contents = $config->getValue($base . "/code/data/" . $fname);
    		
    		# Now write the script to the file.
    		unless (open DATA, ">", "$ddir/$fname") {
    			$self->error("Cannot open file $ddir/$fname for writing: $!");
    			return 0;
    		}
    		print DATA $contents;
    		unless (close DATA){
    			$self->error("Cannot close file $ddir/$fname");
    		}
    	}
    }
    return 1;
}

=pod

=head2 Private methods

=item _initialize($comp_name, $config, $node)

object initialization (done via new)

=cut

sub _initialize {
	my ($self, $comp, $cfg, $node, $connection) = @_;
	$self->setup_reporter();
	unless (defined $comp and defined $cfg and defined $node and defined $connection) {
		throw_error('bad initialization');
		return undef;
	}
	
	unless ($comp =~ m{^([a-zA-Z_]\w+)$}) {
		throw_error('Bad component name: $comp');
		return undef;
	}
	
	$self->{'NAME'} = $1;
	my $name = $self->{'NAME'};
	$self->{'CONFIG'} = $cfg;
	$self->{'NODE'} = $node;
	$self->{'CONNECTION'} = $connection;
	
	# determine the prefix for the perl modules 
	my $prefix = $self->{'CONFIG'}->getElement(NAMESPACE)->getTree();
	if (not defined $prefix) {
		$ec->ignore_error();
		$self->error("Cannot find namespace prefix in \"$node\" profile with path " . NAMESPACE);
		return undef;
	}
	$self->{'NAMESPACE_PREFIX'} = $prefix;
	$self->{'NAMESPACE_DIR'} = $self->{'NAMESPACE_PREFIX'};
	$self->{'NAMESPACE_DIR'} =~ s/::/\//g;
	
	# check for existing and 'active' in node profile
    # actual componenet doesn't get loaded yet, this gets done at execute()
    
    my $cdb_entry = $self->{'CONFIG'}->getElement(COMP_PREFIX . "/$name");
    if (not defined $cdb_entry) {
    	$ec->ignore_error();
    	$self->error("no such component in node \"$node\" profile: " . $name);
    	return undef;
    }
    
    my $prop = $self->{'CONFIG'}->getElement(COMP_PREFIX . "/" . $name . "/active");
    if (not defined $prop) {
    	$ec->ignore_error();
    	$self->error('component ' . $name .
    	               " 'active' flag not found in node $node profile");
    	return undef;
    } else {
    	my $active = $prop->getBooleanValue();
    	if ($active ne 'true') {
    		$self->error('component ' . $name . "is not active for node $node");
    		return undef;
    	}
    	return ($self->_setDependencies());
    }
}

=pod

=item _setDependencies(): boolean

Reads the dependencies on other components via the NVA API and stores them 
internally. They can be recovered by getDependencies()

=cut

sub _setDependencies {
	my ($self) = @_;
	
	$self->{'PRE_DEPS'} = [()];
	$self->{'POST_DEPS'} = [()];
	
	my $conf = $self->{'CONFIG'};
	my $pre_path = COMP_PREFIX.'/'.$self->{'NAME'}.'/dependencies/pre';
    my $post_path = COMP_PREFIX.'/'.$self->{'NAME'}.'/dependencies/post';
	
	# check if paths are defined (otherwise no dependencies)
	
	my $res = $conf->getElement($pre_path);
	if (defined $res) {
		foreach my $el ($res->getList()) {
			push (@{$self->{'PRE_DEPS'}}, $el->getStringValue());
		}
		$self->debug(2, "Pre dependencies for component $self->{NAME} on node $self->{NODE}: " .
		                 join(",", @{$self->{'PRE_DEPS'}}));
	} else {
		$ec->ignore_error();
		$self->debug(1, "No pre dependencies found for " . $self->{"NAME"} . " on node $self->{NODE}");
	}
	
	$res = $conf->getElement($post_path);
	if (defined $res) {
		foreach my $el ($res->getList()) {
			push (@{$self->{'POST_DEPS'}}, $el->getStringValue());
		}
		$self->debug(2, "post dependencies for component " . $self->{"NAME"} . " on node $self->{NODE}: " .
		                  join(",", @{$self->{'POST_DEPS'}}));
	} else {
		$ec->ignore_error();
		$self->debug(2, "No post dependencies found for " . $self->{"NAME"} . " on node $self->{NODE}");
	}
	return SUCCESS;
}

=pod

=item _execute

common function for executeConfigure() and executeUnconfigure()

=cut

sub _execute {
	my ($self, $method) = @_;
	
	# load the component
	
	my $retval;
	my $name = $self->name();
	my $component = $self->_load();
	if (not defined $component) {
		$self->error('cannot load component: ' . $name);
		return undef;
	}
	
	# redirect log file to component's logfile
	if ($this_app->option('multilog')) {
		my $logfile = $this_app->option("logdir") . "/component-" . $name . ".log";
		my $objlog = CAF::Log->new($logfile, 'at');
		if (not defined $objlog) {
			$self->error("cannot open component logfile: " . $logfile);
			return undef;
		}
		$self->set_report_logfile($objlog);
	} else {
		$self->set_report_logfile($this_app->{LOG});
	}
	
	$self->log('--------------------------------------------------------');
	
	my $prefix = "";
	if (exists $self->{NAMESPACE_PREFIX}) {
		$prefix = "::" . $self->{NAMESPACE_PREFIX};
	}
	
	my $module_name = $QRC_NAMESPACE . $prefix . "::$self->{'NAME'}";
	
	my $lcNoAct = $LC::Check::NoAction;
	if ($this_app->option('noaction')) {
		$LC::Check::NoAction = 1;
		my $compname = $self->{'NAME'};
		my $noact_supported = undef;
		eval "\$noact_supported = \$$module_name\:\:NoActionSupported;";
		if ($@ || !defined $noact_supported || !$noact_supported) {
			# noaction is not supported by the component, skip execution in fake mode
			$self->info("component $compname has NoActionSupported not defined or to false, skipping noaction run");
			$retval = {
				'WARNINGS' => 0,
				'ERRORS'   => 0
			};
			return $retval;
		} else {
			$self->info("note: running component $compname in noaction mode");
		}
	}
	
	# execute component
	my $result;
	chdir ('/tmp');
	# FIXME, is next line needed?
	NCM::Template->SetDelimiters(@_TEMPLATE_DELIMITERS);
	my %ENV_BK = %ENV;
	$SIG{$_} = 'IGNORE' foreach qw(HUP PIPE ALRM);
	
	# run the actual component
        eval {
            $result = $component->$method($self->{NODE}, $self->{CONFIG}, $self->{CONNECTION});
        };
	
	%ENV = %ENV_BK;
	if ($@) {
		$component->error("component " . $name . " executing method $method fails: $@");
        }
	my $comp_EC;
	eval "\$comp_EC = \$$module_name\:\:EC;";
	if (not $@) {
		if ($comp_EC->error) {
			$self->error('uncaught error exception in component:');
			my $formatter = $this_app->option('verbose') ||
			    $this_app->option('debug') ? "format_long" : "format_short";
			$component->error($comp_EC->error->$formatter());
			$comp_EC->ignore_error()
		}
		if ($comp_EC->warnings) {
			$self->warn('uncaught warning exception in component:');
			my $formatter = $this_app->option('verbose') || 
			    $this_app->option('debug') ? "format_long" : "format_short";
			foreach ($comp_EC->warnings) {
				$component->warn($_->$formatter())
			}
			$comp_EC->ignore_warnings()
		}
	}
		
	if ($ec->error) {
		$self->error('error exception thrown by component:');
		my $formatter = $this_app->option('verbose') ||
		     $this_app->option('debug') ? "format_long" : "format_short";
		$component->error($ec->error->$formatter());
		$ec->ignore_error();
	}
	if ($ec->warnings) {
		$self->warn('warning exception thrown bu component:');
		my $formatter = $this_app->option('verbose') || 
		     $this_app->option('debug') ? "format_long" : "format_short";
		foreach ($ec->warnings) {
			$component->warn($_->$formatter());
		}
		$ec->ignore_warnings()
	}
		
	$self->info('configure on component ' . $name . ' executed, '.
	             $component->get_errors() . ' errors, ' .
	             $component->get_warnings() . ' warnings');
		             
	$retval = {
		'WARNINGS' => $component->get_warnings(),
		'ERRORS'   => $component->get_errors()
	};

	# restore logfile and noaction flags
	$self->set_report_logfile($this_app->{'LOG'}) if ($this_app->option('multilog'));
	$LC::Check::Noaction = $lcNoAct;
	return $retval;
}

=pod 

=item _load(): boolean

loads the component file in a separate namespace ($NAMESPACE_PREFIX::$name)

=cut

sub _load {
	my ($self) = @_;
	my $compname = $self->{'NAME'};
	
	#if (not $self->writeComponent()) {
	#	if (not $self->hasFile()) {
	#		$self->error('component ' . $compname . ' is not installed in ' . $self->dirname());
	#		return undef;
	#	}
	#}
	
	my $namespace_prefix = "";
	if (defined $self->{NAMESPACE_PREFIX}) {
		$namespace_prefix = "::" . $self->{NAMESPACE_PREFIX};
	}
	my $module_name =  $QRC_NAMESPACE . $namespace_prefix . "::$compname";
	eval ("use $module_name;");
	if ($@) {
		$self->error("bad Perl code in $module_name : $@");
		return undef;
	}
	
	my $comp_EC;
	eval "\$comp_EC = \$$module_name\:\:EC;";
	if ($@ || ! defined $comp_EC || ref($comp_EC) ne 'LC::Exception::Context') {
		$self->error('bad component exception handler: $EC is not defined, not accessible or not of type LC::Exception::Context');
		my $errstr = "note 1: the component package name has to be exactly \"$module_name\" ";
		$errstr .= "- please verify this inside \"" . $self->filename();
        $self->error($errstr);
		$self->error('note 2: $EC has to be declared with "our" or "use vars (...)"');
		return undef;
	}
	
	my $component;
	eval("\$component = $module_name->new(\$compname, \$self)");
	if ($@) {
		$self->error("component $compname instantiation statement fails: $@");
		return undef;
	}
	return $component;
}



























