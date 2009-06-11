# norootforbuild

Summary:   Tool to create SLE/SUSE remote build trees
Name:      baracus
Version:   0.19
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
Source5:   apache.baracus.conf
Requires:  perl, perl-XML-Simple, perl-libwww-perl, perl-Data-UUID
Requires:  perl-Config-General, perl-Config-Simple, perl-AppConfig
Requires:  perl-TermReadKey, perl-DBI, perl-DBD-Pg, perl-Tie-IxHash
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
Baracus is a collection of tools to simplify the retrevial of distribution
and add-on media, building distribution trees, creation and management of
a network install server, and maintain a collection of build templates for
rapid PXE boot installs of a collection of build clients.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -r $PWD/* %{buildroot}/.

install -D -m644 %{S:1} %{buildroot}/var/adm/fillup-templates/sysconfig.%{name}
install -D -m755 %{S:2} %{buildroot}%{_initrddir}/%{name}d
ln -s ../..%{_initrddir}/%{name}d %{buildroot}%{_sbindir}/rc%{name}d
install -D -m644 %{S:3} %{buildroot}/var/adm/fillup-templates/sysconfig.%{name}db
install -D -m755 %{S:4} %{buildroot}%{_initrddir}/%{name}db
ln -s ../..%{_initrddir}/%{name}db %{buildroot}%{_sbindir}/rc%{name}db
install -D -m644 %{S:5} %{buildroot}/etc/apache2/conf.d/%{name}.conf

chmod -R 700 %{buildroot}%{_datadir}/%{name}/gpghome
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
%restart_on_update baracusdb baracusd apache2
%insserv_cleanup

%files
%defattr(-,root,root)
/var/adm/fillup-templates/*
%doc %{_mandir}/man?/*
%{_sbindir}/*
%{_sysconfdir}/%{name}.d
%config %{_initrddir}/%{name}d
%config %{_initrddir}/%{name}db
%dir %{_datadir}/%{name}
%doc %{_datadir}/%{name}/*.xml
%{_datadir}/%{name}/pxelinux.0
%{_datadir}/%{name}/driverupdate
%{_datadir}/%{name}/templates
%{_datadir}/%{name}/perl
%{_datadir}/%{name}/gpghome
%defattr(-,baracus,users)
/var/spool/%{name}
%dir %{_sysconfdir}/apache2
%dir %{_sysconfdir}/apache2/conf.d
%config %{_sysconfdir}/apache2/conf.d/%{name}.conf

