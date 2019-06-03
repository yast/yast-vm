#
# spec file for package yast2-vm
#
# Copyright (c) 2018 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#

Name:           yast2-vm
Summary:        Configure Hypervisor and Tools for Xen and KVM
Version:        4.2.0
Release:        0
Group:          System/YaST
License:        GPL-2.0-only
Url:            https://github.com/yast/yast-vm

Source0:        %{name}-%{version}.tar.bz2

BuildRequires:	perl-XML-Writer update-desktop-files yast2 yast2-testsuite
BuildRequires:  yast2-bootloader >= 3.1.35
BuildRequires:  yast2-devtools >= 4.2.2

# OSRelease
Requires:       yast2 >= 3.0.4
Requires:       yast2-ruby-bindings >= 1.0.0
Requires:       yast2-network >= 3.1.108
Requires:       yast2-bootloader >= 3.1.35

%description
This YaST module installs the tools necessary for creating VMs with Xen or KVM.

%prep
%setup -q

%build
%yast_build

%install
%yast_install

%ifarch %ix86
rm -f $RPM_BUILD_ROOT/usr/share/applications/YaST2/virtualization-config.desktop
rm -f $RPM_BUILD_ROOT/usr/share/applications/YaST2/relocation-server.desktop
rm -rf $RPM_BUILD_ROOT/usr/share/icons/*
%else
%yast_metainfo
%endif

%files
%{yast_clientdir}
%{yast_moduledir}
%{yast_yncludedir}
%{yast_scrconfdir}
%ifnarch %ix86
%{yast_desktopdir}
%{yast_icondir}
%{yast_metainfodir}
%endif
%doc %{yast_docdir}
%license %{yast_docdir}/COPYING
