# norootforbuild

Summary:   Tool to create SLE/SUSE remote build trees and manage host builds
Name:      baracus
Version:   1.3.3
Release:   0
Group:     System/Services
License:   GPLv2
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
Source:    %{name}-%{version}.tar.bz2
Source1:   sysconfig.%{name}
Source2:   initd.%{name}d
Source3:   sysconfig.%{name}db
Source4:   initd.%{name}db
Source5:   apache.baracus.conf
Source6:   initrd.baracus
Source7:   linux.baracus
Requires:  apache2, apache2-mod_perl, perl-Apache-DBI, pidentd
Requires:  perl, perl-XML-Simple, perl-libwww-perl, perl-Data-UUID
Requires:  perl-Config-General, perl-Config-Simple, perl-AppConfig
Requires:  perl-TermReadKey, perl-DBI, perl-DBD-Pg, perl-Tie-IxHash
Requires:  rsync, dhcp-server, postgresql-server, createrepo, fence
Requires:  samba, samba-client
%if 0%{?suse_version} < 1030
Requires:  nfs-utils
%else
Requires:  nfs-kernel-server
%endif

PreReq:    %insserv_prereq %fillup_prereq pwdutils
PreReq:    /usr/sbin/groupadd /usr/sbin/useradd /sbin/chkconfig

%description
Baracus is a collection of tools to simplify the retrevial of distribution
and add-on media, building distribution trees, creation and management of
a network install server, and maintain a collection of build templates for
rapid PXE boot installs of a collection of build clients.

%prep
%setup -q

%build

%install
mkdir -p %{buildroot}
cp -r $PWD/* %{buildroot}/.

install -D -m644 %{S:1} %{buildroot}/var/adm/fillup-templates/sysconfig.%{name}
install -D -m755 %{S:2} %{buildroot}%{_initrddir}/%{name}d
ln -s ../..%{_initrddir}/%{name}d %{buildroot}%{_sbindir}/rc%{name}d
install -D -m644 %{S:3} %{buildroot}/var/adm/fillup-templates/sysconfig.%{name}db
%if 0%{?suse_version} > 1110
sed -ire 's/ident sameuser/ident/' %{S:4}
%endif
install -D -m755 %{S:4} %{buildroot}%{_initrddir}/%{name}db
ln -s ../..%{_initrddir}/%{name}db %{buildroot}%{_sbindir}/rc%{name}db
install -D -m644 %{S:5} %{buildroot}/etc/apache2/conf.d/%{name}.conf
install -D -m644 %{S:6} %{buildroot}%{_datadir}/%{name}/data/initrd.%{name}
install -D -m644 %{S:7} %{buildroot}%{_datadir}/%{name}/data/linux.%{name}
chmod -R 700 %{buildroot}%{_datadir}/%{name}/gpghome
mkdir %{buildroot}/var/spool/%{name}/isos
mkdir %{buildroot}/var/spool/%{name}/logs
mkdir %{buildroot}/var/spool/%{name}/modules
mkdir %{buildroot}/var/spool/%{name}/pgsql
rm -rf %{buildroot}/var/spool/baracus/www/pfork

%clean
rm -rf %{buildroot}

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
%restart_on_update baracusdb baracusd apache2
%insserv_cleanup

%files
%defattr(-,root,root)
/var/adm/fillup-templates/*
%doc %{_mandir}/man?/*
%{_sbindir}/*
%config %{_initrddir}/%{name}d
%config %{_initrddir}/%{name}db
%dir %{_datadir}/%{name}
%doc %{_datadir}/%{name}/*.xml
%{_datadir}/%{name}/data
%{_datadir}/%{name}/driverupdate
%{_datadir}/%{name}/profile_default
%{_datadir}/%{name}/templates
%{_datadir}/%{name}/perl
%{_datadir}/%{name}/gpghome
%{_datadir}/%{name}/scripts
%dir %{_sysconfdir}/apache2
%dir %{_sysconfdir}/apache2/conf.d
%config %{_sysconfdir}/apache2/conf.d/%{name}.conf
%attr(755,baracus,users) %dir /var/spool/%{name}
%attr(755,baracus,users) /var/spool/%{name}/builds
%attr(755,root,root) /var/spool/%{name}/isos
%attr(755,root,root) /var/spool/%{name}/logs
%attr(755,root,root) /var/spool/%{name}/hooks
%attr(755,root,root) /var/spool/%{name}/pgsql
%attr(755,root,root) /var/spool/%{name}/modules
%attr(755,root,root) /var/spool/%{name}/templates
%attr(755,root,root) /var/spool/%{name}/www
%attr(-,wwwrun,www) %dir /var/spool/%{name}/www/tmp
%attr(-,wwwrun,www) %dir /var/spool/%{name}/www/htdocs/pool

%changelog
* Thu Apr 10 2010 dbahi@novell - 1.3.3
- repackage for cifs share and win install support
* Wed Mar 10 2010 dbahi@novell - 1.3.2
- additional iscsi support work
- virsh now supported in bapower
- remote flash vnc viewer in web gui
- windows vista, 2008 and 7 build support
* Fri Jan 29 2010 dbahi@novell - 1.3.1
- minor release with major web integration work.
- web usage of the bado balog bahost bastorage bapower cmds
- bapower working with virsh and hostnames to launch kvm VMs
- VNC java applet viewer launch kvm VMs in web gui as a tab
- bastorage a new network boot disk location information tool 
* Tue Jan 12 2010 dbahi@novell - 1.3
- ba tools reworked so that the majority of code
  is contained in functional modules
- database cleanup and reorder
- gpxe iscsi netbooting supported
- rescue and norescue host modes supported
- support for prompted install (--autobuild none) option
* Thu Dec 10 2009 dbahi@novell - 1.2
- enhanced functionality of bapower
- more details of host state and transitions
- remote logging for rhel and suse families
- baracusdb has distinct port 5162 from pgsql
* Fri Nov 20 2009 dwestervelt@novell - 1.11
- Initial release of bapower BMC power control command
- currently supports IMPI
- support on,off,cycle,status,add functions 
* Fri Nov 20 2009 dbahi@novell - 1.10
- a massive shift forward in functionality
- http cgi based serving gpxe fetched boot files
- cradle, read inventory, to grave, read dban, host building
- baracus is basource, barepo, baconfig, bahost, and bapower
- baracus is also a db, tftp server, boot manager with a web interface
* Tue Jun 10 2009 dbahi@novell - 0.19
- westervelt - added schema for distro, hardware, modules vs files
- added code create_install_config to work distro, hardware, modules
- added code to refer to distro and hardware tables in bahost
- first pass at enum/constant for state representation
- created symlinks basource bahost and baconfig
- westervelt - added create/modified schema to source registration
- westervelt - modified basource to work maintain source registration
- modified baracusd and verify_client hooks to better handle mult tftp req
- massively reduced demo templates and entirely rid of packages-remove list
- bahost hwtype changed to hardware to paramater agrees with variable
- fix nfs basource enable/disable entry handling
- add hae and mono entries to os.config (even though it'll soon disappear)
- add sda and hda to kvm descript in hardware.config for better web experience
- westervelt - creation of HAE and MONO templates
- mtaylor - initial population of the BA webserver pages and scripts
- added sles9 template.xml.example
- modified os.config for sles9 and addition of sle10 MONO add-on
- modify autoinstall templates cleanup
- added hardware and distro loading scripts
- modify baracusInitDB to call hardware and distro loading scripts
- remove obsolete hardware.config and os.config
- added driverupdate sle10SP2-sle11GA x86/x86_64 autoyast tftp last ACK fix
- modify basource to install driverupdate for sle10 (commented out for sle11)
- mtaylor - mods to www for new baconfig distro and hardware
- mtaylor - moved web server pages to baracus home
- added baracus.conf apache config for baracus web server
- added source control utilities find_dos_files and list_svn_at_root
- removed executable bits on sles9 templates
* Tue May 19 2009 dbahi@novell
- shift BUILDIP check to be after help checks
- source add / remove / enable / disable modifies service
- source restarts service if related config modified
- fix for verify of add-ons and for rename of slert to slert10
- pxetemplate cleanup for sqltftp service
* Mon May 18 2009 dwestervelt@novell
- support for multiple sles11 addons via add_on_product.xml
- adds targets for SLES11 HAE and SLES11 Mono addons
- rough outline of man pages atortola@novell
* Wed May 13 2009 dwestervelt@novell  
- conversion to postgresql completed with conversion  
  of add/update/remove triggers to maintain history  
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
