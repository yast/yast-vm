#
# spec file for package yast2-vm
#
# Copyright (c) 2015 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-vm
Version:        3.1.21
Release:        0
Group:		System/YaST

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

ExclusiveArch:  %ix86 x86_64 s390x
BuildRequires:	perl-XML-Writer update-desktop-files yast2 yast2-testsuite
BuildRequires:  yast2-bootloader >= 3.1.35
BuildRequires:  yast2-devtools >= 3.1.10
License:        GPL-2.0

# OSRelease
Requires:	yast2 >= 3.0.4

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	Configure Hypervisor and Tools for Xen and KVM

%description
This YaST module installs the tools necessary for creating VMs with Xen or KVM.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install

%ifarch %ix86
rm -f $RPM_BUILD_ROOT/usr/share/applications/YaST2/virtualization-config.desktop
rm -f $RPM_BUILD_ROOT/usr/share/applications/YaST2/relocation-server.desktop
%endif


%files
%defattr(-,root,root)
%dir %{yast_scrconfdir}
%dir %{yast_yncludedir}
%{yast_clientdir}/relocation-server.rb
%{yast_clientdir}/virtualization.rb
%{yast_clientdir}/vm_finish.rb
%{yast_moduledir}/VirtConfig.rb
%{yast_moduledir}/RelocationServer.*
%{yast_yncludedir}/*
%{yast_scrconfdir}/*
%{yast_desktopdir}/groups/virtualization.desktop
%ifnarch %ix86
%{yast_desktopdir}/relocation-server.desktop
%{yast_desktopdir}/virtualization-config.desktop
%endif
%doc %{yast_docdir}
%doc %{yast_docdir}/COPYING
