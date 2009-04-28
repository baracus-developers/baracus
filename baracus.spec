# norootforbuild

Summary:   Tool to create SLE/SUSE remote build trees
Name:      baracus
Version:   0.16
Release:   0
Group:     System/Services
License:   GPLv2
Packager:  Daniel Westervelt <dwestervelt@novell.com>
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
Source:    %{name}-%{version}.tar.gz
Source1:   sysconfig.%name
Requires:  perl, perl-XML-Simple, perl-libwww-perl, perl-Data-UUID
Requires:  perl-Config-General, perl-Config-Simple, perl-AppConfig
Requires:  perl-TermReadKey, perl-DBI, perl-DBD-SQLite, rsync
%if 0%{?suse_version} <= 1100
Requires:  sqlite > 3.2
%else
Requires: sqlite3
%endif
Obsoletes: create_install_source < 1.25
PreReq:    %insserv_prereq %fillup_prereq

%description
Baracus is part of the larger Novell migration tools aimed at stream-
lining the migration from other Linux distributions to SLES.  The tool 
automates the creation of NFS and/or HTTP remote build trees.  This includes 
configuring tftp, pxe, dhcpd, nfs and/or httpd as well as building the 
necessary distribution tree.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -r $PWD/* %{buildroot}/.

chmod 755 %{buildroot}/%{_initrddir}/%{name}d
install -D -m644 %{S:1} %{buildroot}/var/adm/fillup-templates/sysconfig.baracus
ln -s ../..%{_initrddir}/%{name}d %{buildroot}/%{_sbindir}/rc%{name}d
mkdir %{buildroot}/var/spool/%{name}/isos

%clean
rm -Rf %{buildroot}

%post
%{fillup_only}
%{fillup_and_insserv -f -y baracusd}

%preun
%stop_on_removal baracusd

%postun
%restart_on_update baracusd
%insserv_cleanup


%files
%defattr(-,root,root)
#%doc %{_mandir}/man?/*
%{_sbindir}/*
%{_sysconfdir}/baracus.d
%config %{_initrddir}/baracusd
%dir %{_datadir}/baracus
%doc %{_datadir}/baracus/*.xml
%{_datadir}/baracus/pxelinux.0
%{_datadir}/baracus/templates
%{_datadir}/baracus/perl
%{_datadir}/baracus/.gnupg
/var/spool/%{name}
%dir /var/spool/%{name}/modules
%dir /var/spool/%{name}/logs
%dir /var/spool/%{name}/isos
/var/adm/fillup-templates/*

%changelog
* Fri Apr 10 2009 dbahi@novell
- add golden image templates for pxe and autoyast
- change -i handling and avoid clobbering files we have
* Wed Apr 08 2009 dbahi@novell
- simplify spec file and set sysconfig file suse style
- baracus obsoletes create_install_source package
* Wed Jan 28 2009 Daniel Westervelt <dwestervelt@novell.com> 1.13.0
- fixed processing of addon products like slert and OES
- added more error checking
* Fri Jan 16 2009 Daniel Westervelt <dwestervelt@novell.com> 1.12-0
- added missing /srv/tftpboot/pxelinux.0
- added atftpd as a rpm dependency
* Tue Jan 13 2009 Daniel Westervelt <dwestervelt@novell.com> 1.10-0
- corrected spec file for 11.1
* Mon Jan 12 2009 Daniel Westervelt <dwestervelt@novell.com> 1.9-0
- removed iso md5 for non-download unless "-c" is specified
- moved config files and templates to /usr/share/create_install_source
- corrected path typo for http configuration
* Fri Jan 9 2009 Daniel Westervelt <dwestervelt@novell.com> 1.8-0
- added check for root uid
- added support for case insensitivity in responses
- added check on distribution selection
- added GPL statement
* Mon Jan 5 2009 Daniel Westervelt <dwestervelt@novell.com> 1.7-0
- added verbose run mode
* Fri Jan 2 2009 Daniel Westervelt <dwestervelt@novell.com> 1.5-0
- added pxe support
- added remote download of iso files
- fixed writing zero length iso files
- cleaned up menu interface
- added proxy support
* Tue Oct 7 2008 Daniel Westervelt <dwestervelt@novell.com> 1.0-0
- initial build
