#
# Generic component spec file
#
# German Cancio <German.Cancio@cern.ch>
#
#

Summary: @DESCR@
Name: @NAME@
Version: @VERSION@
Vendor: @VENDOR@
Release: @RELEASE@
License: @LICENSE@
Group: @GROUP@
Source: @TARFILE@
BuildArch: noarch
BuildRoot: /var/tmp/%{name}-build
Packager: @AUTHOR@
Requires: perl-CAF >= 1.6.5
Requires: perl-LC
Requires: ccm >= 1.1.6
Requires: ncm-template >= 1.0.8

URL: @QTTR_URL@

%description

quattor (@QTTR_URL@) quattor-remote-configure

@DESCR@

%prep
%setup

%build
make

%install
rm -rf $RPM_BUILD_ROOT
make PREFIX=$RPM_BUILD_ROOT install

%files
%defattr(-,root,root)
@QTTR_SBIN@/@COMP@
@QTTR_PERLLIB@/Quattor/
@QTTR_ROTATED@/@COMP@
@QTTR_ETC@/@COMP@.conf
@QTTR_LOCKD@/

%doc @QTTR_DOC@/
%doc @QTTR_MAN@/man@MANSECT@/*
%doc @QTTR_MAN@/man3/*

%clean
rm -rf $RPM_BUILD_ROOT
