# norootforbuild

Summary:   Tool to create network install build source and manage host builds
Name:      baracus
Version:   1.7.2
Release:   0
Group:     System/Services
License:   GPLv2 or Artistic V2
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
Source:    %{name}-%{version}.tar.bz2
Source1:   sysconfig.%{name}
Source2:   initd.%{name}d
Source3:   sysconfig.%{name}db
Source4:   initd.%{name}db
Source5:   apache.baracus.conf
Source6:   apache.baracus-webserver.conf
#Source7:   Makefile
Requires:  apache2, apache2-mod_perl, perl-Apache-DBI, pidentd, sudo
Requires:  perl, perl-XML-Simple, perl-libwww-perl, perl-Data-UUID
Requires:  perl-Config-General
Requires:  perl-TermReadKey, perl-DBI, perl-DBD-Pg, perl-Tie-IxHash
Requires:  perl-IO-Interface, perl-Net-Netmask, perl-XML-LibXSLT
Requires:  rsync, dhcp-server, postgresql-server, createrepo, fence
Requires:  samba, samba-client, ipmitool, dropbear, fuse-funionfs
Requires:  baracus-kernel
BuildRequires: gcc-c++
%if 0%{?suse_version} < 1030
Requires:  nfs-utils
%else
Requires:  nfs-kernel-server
%endif
%if 0%{?suse_version} >= 1110
Requires:  libvirt
%endif
# Remote logging requires syslog-ng installed
Requires:  syslog-ng

PreReq:    %insserv_prereq %fillup_prereq pwdutils
PreReq:    /usr/sbin/groupadd /usr/sbin/useradd /sbin/chkconfig

%description
Baracus is a collection of tools to simplify the retrevial of distribution
and add-on media, building distribution trees, creation and management of
a network install server, and maintain a collection of build templates for
rapid PXE boot installs of a collection of build clients.


%package   webserver
Summary:   Separate package for the baracus server web interface
Group:     System/Services
Requires:  baracus = %{version}
%description webserver
Baracus is composed of many services and a command line interface.
This package provides a web interface to these services.

%prep
%setup -q

%build
pushd usr/share/baracus/utils
CFLAGS="$RPM_OPT_FLAGS" CPPFLAGS="$RPM_OPT_FLAGS" make
popd

%install
# do not use the make install target from top level
mkdir -p %{buildroot}
cp -r ${PWD}/* %{buildroot}/.

rm          %{buildroot}/var/spool/baracus/www/htdocs/blank.html
rm    -rf   %{buildroot}/var/spool/baracus/templates
mkdir       %{buildroot}/var/spool/baracus/isos
mkdir       %{buildroot}/var/spool/baracus/images
mkdir       %{buildroot}/var/spool/baracus/logs
mkdir       %{buildroot}/var/spool/baracus/pgsql
mkdir       %{buildroot}/var/spool/baracus/www/tmp
mkdir       %{buildroot}/var/spool/baracus/www/htdocs/pool
mkdir -p    %{buildroot}/var/spool/baracus/builds/winstall/import/amd64
mkdir -p    %{buildroot}/var/spool/baracus/builds/winstall/import/x86

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
install -D -m644 %{S:6} %{buildroot}/etc/apache2/conf.d/%{name}-webserver.conf
chmod -R 700 %{buildroot}%{_datadir}/%{name}/gpghome

install -D -m755 %{buildroot}/usr/share/baracus/utils/pfork.bin %{buildroot}/var/spool/%{name}/www/modules/pfork.bin
install -D -m755 %{buildroot}/usr/share/baracus/utils/sparsefile %{buildroot}/usr/bin/sparsefile
rm    -rf   %{buildroot}/usr/share/baracus/utils

rm    -rf   %{buildroot}/etc/modprobe.d/baracus.loop
install -D -m644 %{buildroot}/usr/share/baracus/templates/modprobe.d.max_loop.conf %{buildroot}/etc/modprobe.d/baracus-loop.conf

%clean
rm -rf %{buildroot}

%pre
groupadd -g 162 -o -r baracus >&/dev/null || :  
useradd -g baracus -o -r -d /var/spool/baracus -s /bin/bash -c "Baracus Server" -u 162 baracus >&/dev/null || :  

%post
%{fillup_and_insserv -n baracus baracusd}
%{fillup_and_insserv -n baracusdb baracusdb}

%preun
%stop_on_removal baracusd baracusdb

%postun
%restart_on_update baracusdb baracusd apache2
%insserv_cleanup

%postun webserver
%restart_on_update apache2
%insserv_cleanup

%files webserver
%defattr(-,root,root)
/var/spool/%{name}/www/htdocs
/var/spool/%{name}/www/cgi-bin
%attr(755,wwwrun,www) %dir /var/spool/%{name}/www/htdocs/pool
%config %{_sysconfdir}/apache2/conf.d/%{name}-webserver.conf

%files
%defattr(-,root,root)
/var/adm/fillup-templates/*
%doc %{_mandir}/man?/*
%{_sbindir}/*
%{_bindir}/*
%config %{_initrddir}/%{name}d
%config %{_initrddir}/%{name}db
/etc/modprobe.d
%dir %{_datadir}/%{name}
%dir %{_datadir}/%{name}/data
%doc %{_datadir}/%{name}/*.xml
%doc %{_datadir}/%{name}/doc
%{_datadir}/%{name}/data/*
%{_datadir}/%{name}/profile_default
%{_datadir}/%{name}/templates
%{_datadir}/%{name}/source_handlers
%{_datadir}/%{name}/perl
%{_datadir}/%{name}/gpghome
%{_datadir}/%{name}/scripts
%dir %{_sysconfdir}/apache2
%dir %{_sysconfdir}/apache2/conf.d
%config %{_sysconfdir}/apache2/conf.d/%{name}.conf
%attr(755,baracus,users) %dir /var/spool/%{name}
%attr(755,baracus,users) %dir /var/spool/%{name}/builds
%attr(-,root,root) /var/spool/%{name}/builds/*
%attr(-,root,root) /var/spool/%{name}/isos
%attr(755,baracus,users) /var/spool/%{name}/images
%attr(-,root,root) /var/spool/%{name}/logs
%attr(-,root,root) /var/spool/%{name}/hooks
%attr(-,root,root) /var/spool/%{name}/pgsql
%attr(755,root,root) %dir /var/spool/%{name}/www
%attr(755,root,root) /var/spool/%{name}/www/ba
%attr(755,root,root) /var/spool/%{name}/www/modules
%attr(755,wwwrun,www) %dir /var/spool/%{name}/www/tmp


%changelog
