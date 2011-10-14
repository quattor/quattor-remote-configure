#
# Quattor Remote Component class
#
# Copyright (C) 2009  Contributor
#

package Quattor::Remote::Component;

use strict;
use CAF::Object;
use LC::Exception qw(SUCCESS throw_error);
use Exporter;

our(@ISA, $this_app, @EXPORT, $NoAction);

@ISA = qw(Exporter CAF::Object);
*this_app = \$main::this_app;
@EXPORT = qw($NoAction);

$NoAction = $this_app->option('noaction');

my $EC = LC::Exception::Context->new->will_report_all;

=pod

=head1 NAME

Quattor::Remote::Component - basic support functions for QRCs

=head1 INHERITANCE

    CAF::Object
    
=head1 DESCRIPTION

This class provides the necessary support functions for remote components,
which have to inherit from it. As with NCM this provides aliasing of some 
functions for LCFG backwards compatibility. This may or may not be still 
necessary.

=head1 AUTHOR

Ben Jones <Ben.Jones@morganstanley.com>

=cut

#------------------------------------------------------------------------------
#                          Public Methods/Functions
#------------------------------------------------------------------------------

=pod

=head1 Public methods

=over 4

=item log(@array) or LogMessage(@array)

write @array to remote component's logfile.

=cut

*LogMessage = *log;
sub log {
	my ($self) = @_;
	$self->{LOGGER}->log(@_);
}

=cut

=item report(@array) or Report(@array)

write @array to remote component's logfile and stdout.

=cut

*Report = *report;
sub report {
  my $self=shift;
  $self->{LOGGER}->report(@_);
}

=pod

=item info(@array) or Info(@array)

same as 'report', but string prefixed by [INFO]

=cut

*Info = *info;
sub info {
  my $self=shift;
  $self->{LOGGER}->info(@_);
}

=pod

=item OK(@array)

same as 'report', but string prefixed by [OK]

=cut

sub OK {
  my $self=shift;
  $self->{LOGGER}->OK(@_);
}

=pod

=item verbose(@array) or Verbose(@array)

as 'report' - only if verbose output is activated.

=cut

*Verbose = *verbose;
sub verbose {
  my $self=shift;
  $self->{LOGGER}->verbose(@_);
}

=pod

=item debug($int,@array) or Debug(@array)

as 'report' - only if debug level $int is activated. If called as
Debug(@array), the default debug level is set to 1.

=cut

sub debug {
  my $self=shift;
  $self->{LOGGER}->debug(@_);
}

sub Debug {
  my $self=shift;
  $self->{LOGGER}->debug(1,@_);
}

=pod

=item warn(@array) or Warn(@array)

as 'report', but @array prefixed by [WARN]. Increases the number of
reported warnings by 1.

The ncd will report the number of warnings reported by the component.

=cut

*Warn = *warn;
sub warn {
  my $self=shift;
  $self->{LOGGER}->warn(@_);
  $self->{'WARNINGS'}++;
}

=pod

=item error(@array) or Error(@array)

as 'report', but @array prefixed by [ERROR]. Increases the number of
reported errors by 1. The remote component will therefore be flagged as
failed, and no depending remote components will be executed.

quattor-remote-configure will report the number of errors reported by the 
remote component.

=cut

*Error = *error;
sub error {
  my $self=shift;
  $self->{LOGGER}->error(@_);
  $self->{'ERRORS'}++;
}

=pod

=item name():string

Returns the component name

=cut

sub name {
  my $self=shift;
  return $self->{'NAME'};
}

=pod

=item unescape($string): $string

Returns the unescaped version of the string provided as parameter (as escaped 
by using the corresponding PAN function).

=cut

sub unescape ($) {
  my ($self,$str)=@_;

  $str =~ s!(_[0-9a-f]{2})!sprintf("%c",hex($1))!eg;
  return $str;
}

=pod

=item escape($string): $string

Returns the escaped version of the string provided as parameter (similar to the
corresponding PAN function)

=cut

sub escape ($) {
  my ($self, $str) = @_;

  $str =~ s/(^[0-9]|[^a-zA-Z0-9])/sprintf("_%lx", ord($1))/eg;
  return $str;
}

=pod

=item get_warnings(): integer

Returns the number of calls to 'warn' by the remote component.

=cut

sub get_warnings {
  my $self=shift;

  return $self->{'WARNINGS'};
}

=pod

=item get_errors(): integer

Returns the number of calls to 'error' by the remote component.

=cut

sub get_errors {
  my $self=shift;

  return $self->{'ERRORS'};
}

=pod

=head1 Pure virtual methods

=item Configure($config): boolean

Component Configure method. Has to be overwritten if used.

=cut


sub Configure {
  my ($self,$config)=@_;

  $self->error('Configure() method not implemented by remote component');
  return undef;
}

=pod

=item Unconfigure($config): boolean

Component Unconfigure method. Has to be overwritten if used.

=cut


sub Unconfigure {
  my ($self,$config)=@_;

  $self->error('Unconfigure() method not implemented by remote component');
  return undef;
}

=pod

=head1 Private methods

=item _initialize($comp_name)

object initialization (done via new)

=cut

sub _initialize {
  my ($self, $name, $host, $logger) = @_;

  unless (defined $name) {
    throw_error('bad initialization');
    return undef;
  }
  $self->{'NAME'} = $name;
  $self->{'ERRORS'} = 0;
  $self->{'WARNINGS'} = 0;
  $self->{LOGGER} = defined $logger ? $logger : $this_app;
  return SUCCESS;
}


#+#############################################################################
1;

