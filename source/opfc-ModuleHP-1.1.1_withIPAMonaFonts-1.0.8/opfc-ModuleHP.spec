# -*- coding:utf-8-unix -*-
#
# Copyright (c) 2000-2003 Turbolinux, inc. 
# This file and all modifications and/or additions are under 
# the same license as package itself.

%define _name opfc-ModuleHP
%define _ver  1.1.1
%define _rel  1
%define opfc_prefix opfc-

Summary: OpenPrinting Japan - Hewlett-Packard printer Modules
Summary(ja_JP.utf8): OpenPrinting Japan - HewlettPackardプリンタ用 各種モジュール
Name: %{_name}
Version: %{_ver}
Release: %{_rel}
License: See the COPYING/LICENSE file in each package. 
Group: Applications/System
SOURCE: opfc-ModuleHP-1.1.1.tar.gz
Buildroot: %{_tmppath}/%{name}-root
Requires: opvp >= 1.0.0
BuildRequires: cups-devel

%description
This package is the part of "OpenPrinting Japan API Reference Implementation".

Printer driver modules for HewlettPackard printers.Included are:
 opvpDriver-HP-ColorLaserJet4600 (Vector printer driver for HP-ColorLaserJet4600)
 opvpDriver-HP-ColorLaserJet5500 (Vector printer driver for HP-ColorLaserJet5500)

%package -n %{opfc_prefix}opvpDriver-HP-ColorLaserJet4600
Version: 1.1.1
Summary: Vector printer drivers for HP-ColorLaserJet4600
Summary(ja_JP.utf8): プリンタドライバ - HP-ColorLaserJet4600用
License: See COPYING file
Group: System Environment/Libraries
Requires: opvp >= 1.0.0

%description -n %{opfc_prefix}opvpDriver-HP-ColorLaserJet4600
This package is the part of "OpenPrinting Japan API Reference Implementation".
Vector printer drivers for HewlettPackard ColorLaserJet4600

%description -n %{opfc_prefix}opvpDriver-HP-ColorLaserJet4600 -l ja_JP.utf8
このパッケージにはHewlettPackard ColorLaserJet4600用のプリンタドライバ(Shared library type)が含まれています。

%package -n %{opfc_prefix}opvpDriver-HP-ColorLaserJet5500
Version: 1.1.1
Summary: Vector printer drivers for HP-ColorLaserJet5500
Summary(ja_JP.utf8): プリンタドライバ - HP-ColorLaserJet5500用
License: See COPYING file
Group: System Environment/Libraries
Requires: opvp >= 1.0.0

%description -n %{opfc_prefix}opvpDriver-HP-ColorLaserJet5500
This package is the part of "OpenPrinting Japan API Reference Implementation".
Vector printer drivers for HewlettPackard ColorLaserJet5500

%description -n %{opfc_prefix}opvpDriver-HP-ColorLaserJet5500 -l ja_JP.utf8
このパッケージにはHewlettPackard ColorLaserJet5500用のプリンタドライバ(Shared library type)が含まれています。

%prep
%setup -q -n opfc-ModuleHP-1.1.1

%build
CFLAGS="$RPM_OPT_FLAGS" \
%configure
make

%install
make install DESTDIR=${RPM_BUILD_ROOT}

%clean
rm -rf $RPM_BUILD_ROOT

%post -n %{opfc_prefix}opvpDriver-HP-ColorLaserJet4600 -p /sbin/ldconfig
%postun -n %{opfc_prefix}opvpDriver-HP-ColorLaserJet4600 -p /sbin/ldconfig

%post -n %{opfc_prefix}opvpDriver-HP-ColorLaserJet5500 -p /sbin/ldconfig
%postun -n %{opfc_prefix}opvpDriver-HP-ColorLaserJet5500 -p /sbin/ldconfig

%files -n %{opfc_prefix}opvpDriver-HP-ColorLaserJet4600
%defattr(-,root,root)
%doc COPYING README ChangeLog
%doc README.jp
%{_libdir}/libHPPageColor.so*
%{_datadir}/cups/model/OPVP-HP-Color_LaserJet_4600.ppd

%files -n %{opfc_prefix}opvpDriver-HP-ColorLaserJet5500
%defattr(-,root,root)
%doc COPYING README ChangeLog
%doc README.jp
%{_libdir}/libHPPageColor.so*
%{_datadir}/cups/model/OPVP-HP-Color_LaserJet_5500.ppd

%changelog
* Thu Mar 24 2005 Toshihiro Yamagishi <toshihiro@turbolinux.co.jp> - 1.1.1
- fixed memory leak [opfc:1155]

* Wed Mar 31 2004 Toshihiro Yamagishi<toshihiro@turbolinux.co.jp>
- repackage for Turbolinux
