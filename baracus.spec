# norootforbuild

Summary:   Tool to create SLE/SUSE remote build trees
Name:      baracus
Version:   0.17
Release:   0
Group:     System/Services
License:   GPLv2
Packager:  Daniel Westervelt <dwestervelt@novell.com>
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
Source:    %{name}-%{version}.tar.gz
Source1:   sysconfig.%{name}
Source2:   initd.%{name}d
Source3:   sysconfig.%{name}db
Source4:   initd.%{name}db
Requires:  perl, perl-XML-Simple, perl-libwww-perl, perl-Data-UUID
Requires:  perl-Config-General, perl-Config-Simple, perl-AppConfig
Requires:  perl-TermReadKey, perl-DBI, perl-DBD-Pg
Requires:  rsync, apache2, dhcp-server, postgresql-server
%if 0%{?suse_version} < 1030
Requires:  nfs-utils
%else
Requires:  nfs-kernel-server
%endif
Obsoletes: create_install_source < 1.25
PreReq:    %insserv_prereq %fillup_prereq pwdutils
PreReq:    /usr/sbin/groupadd /usr/sbin/useradd /sbin/chkconfig

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

install -D -m644 %{S:1} %{buildroot}/var/adm/fillup-templates/sysconfig.%{name}
install -D -m755 %{S:2} %{buildroot}/%{_initrddir}/%{name}d
install -D -m644 %{S:3} %{buildroot}/var/adm/fillup-templates/sysconfig.%{name}db
install -D -m755 %{S:4} %{buildroot}/%{_initrddir}/%{name}db
ln -s ../..%{_initrddir}/%{name}d %{buildroot}/%{_sbindir}/rc%{name}d
ln -s ../..%{_initrddir}/%{name}db %{buildroot}/%{_sbindir}/rc%{name}db
chmod 755 %{buildroot}/%{_initrddir}/%{name}d
chmod 755 %{buildroot}/%{_initrddir}/%{name}db
chmod -R 700 %{buildroot}/%{_datadir}/%{name}/.gnupg
mkdir %{buildroot}/var/spool/%{name}/isos
mkdir %{buildroot}/var/spool/%{name}/logs
mkdir %{buildroot}/var/spool/%{name}/modules
mkdir %{buildroot}/var/spool/%{name}/pgsql

%clean
rm -Rf %{buildroot}

%pre
groupadd -g 162 -o -r baracus >&/dev/null || :  
useradd -g baracus -o -r -d /var/spool/baracus -s /bin/bash -c "Baracus Server" -u 162 baracus >&/dev/null || :  

%post
%{fillup_only -n baracusdb}
%{fillup_only}
%{fillup_and_insserv -f -y baracusdb}
%{fillup_and_insserv -f -y baracusd}

%preun
%stop_on_removal baracusd baracusdb

%postun
%restart_on_update baracusdb baracusd
%insserv_cleanup

%files
%defattr(-,root,root)
/var/adm/fillup-templates/*
#%doc %{_mandir}/man?/*
%{_sbindir}/*
%{_sysconfdir}/%{name}.d
%config %{_initrddir}/%{name}d
%config %{_initrddir}/%{name}db
%dir %{_datadir}/%{name}
%doc %{_datadir}/%{name}/*.xml
%{_datadir}/%{name}/pxelinux.0
%{_datadir}/%{name}/templates
%{_datadir}/%{name}/perl
%defattr(-,baracus,users)
%{_datadir}/%{name}/.gnupg
/var/spool/%{name}
%dir /var/spool/%{name}/isos
%dir /var/spool/%{name}/logs
%dir /var/spool/%{name}/modules
%dir /var/spool/%{name}/pgsql

%changelog
* Sun May 10 2009 dbahi@novell
- added initdb script to initd.baracusdb
  to initialize the role and required databases
- added 'list' functionality to sqlfs and directsqlfs
- corrected DATE to TIMESTAMP for timestamps
* Fri May  8 2009 dbahi@novell
- moved underlying db from sqlite to postgresql
- build complete hooks more clearly named
- support for build verification failure hook
- major parameter handling cleanup and help rework
- baracusdb addition for our own instance of postgres
* Mon Apr 27 2009 dbahi@novell
- all tftp files served from db directly
- baracusd no longer depends on apache2
- symlink example templates for slert, sle10, sle11 x86_64
- key added to initrd for sle11 add_on_product handling
- modify perms for gnupg directory
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
