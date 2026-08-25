Name:       harbour-fiatagenda
Summary:    A fast, minimal task list
Version:    0.1.0
Release:    1
License:    MIT
URL:        https://github.com/munksh/FiatAgenda
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 0.10.9
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  desktop-file-utils

# Note: QtQuick.LocalStorage and Nemo.Configuration both ship with the OS.
# Do NOT add Requires: lines for them -- nemo-qml-plugin-configuration does
# not exist as a package and the install will fail with "Paketet hittades ej".
#
# Do NOT use %%qtc_qmake5 / %%qtc_make / %%qmake5_install here. Those macros
# are Qt Creator's own and are not defined in this build target; an undefined
# macro passes through literally and the build dies with "fg: no job control"
# -- or worse, the install section runs and installs nothing, and the app
# starts with no QML to load.
#
# And note the doubled percent signs above. rpm expands macros INSIDE COMMENTS
# too. A bare %%install written in prose here expands to the real thing, which
# carries %%debug_package with it -- so the debuginfo subpackage gets declared
# from the comment, and then again from the actual section further down:
#     error: line NN: %%package debuginfo: package NAME-debuginfo already exists
# Every percent sign in a comment in this file is doubled on purpose.

%description
Fiat Agenda is a personal task list. Fast capture, dates, one level of
subtasks, simple lists and recurring tasks -- and nothing that would only
matter to someone managing work across a team.

Today and Upcoming are computed from the dates, never curated. Capture
inherits the view you are standing in: type in Today and the task is due
today, type inside a list and it joins that list. Deletion is a real delete
behind the standard remorse timer; there is no hidden history.

Everything stays in one file on your phone. No account, no network access,
no telemetry.

Fourth in the Fiat family, after Fiat Lux (a light meter), Fiat Vox (a tuner)
and Fiat Mos (a habit tracker).

%if 0%{?_chum}
Title: Fiat Agenda
Type: desktop-application
DeveloperName: Munkstolen
Categories:
 - Utility
 - Office
Custom:
  Repo: https://github.com/munksh/FiatAgenda
Links:
  Homepage: https://github.com/munksh/FiatAgenda
  Bugtracker: https://github.com/munksh/FiatAgenda/issues
%endif

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
make install INSTALL_ROOT=%{buildroot}
desktop-file-install --delete-original \
  --dir %{buildroot}%{_datadir}/applications \
  %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
