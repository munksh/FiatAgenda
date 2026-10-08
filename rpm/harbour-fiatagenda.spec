Name:       harbour-fiatagenda
Summary:    A fast, minimal task list
Version:    1.2
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

# QtQuick.LocalStorage and Nemo.Configuration both ship with the OS. Do NOT
# add Requires: lines for them -- nemo-qml-plugin-configuration does not exist
# as a package and the install fails with "Paketet hittades ej".
#
# Do NOT use %%qtc_qmake5 / %%qtc_make / %%qmake5_install here. Those macros
# are Qt Creator's own and are undefined in this build target; an undefined
# macro passes through literally and the build dies with "fg: no job control"
# -- or worse, the install section runs and installs nothing, and the app
# starts with no QML to load.
#
# Note the doubled percent signs above. rpm expands macros INSIDE COMMENTS,
# so a bare %%install written in prose expands to the real thing, carries
# %%debug_package with it, and the debuginfo subpackage gets declared twice:
#     error: line NN: %%package debuginfo: package NAME-debuginfo already exists
# Every percent sign in a comment in this file is doubled on purpose.

%description
Buy milk. Call the dentist before Friday. Water the plants every Sunday, for
as long as there are plants.

Most task apps want to know the project, the tag and the priority before they
will let you write anything down. fiat agenda asks for the words. A date is
optional, a time is optional, and no date at all is a proper answer rather
than an unfinished one.

CAPTURE
The field is always there at the bottom of the list. Type, press return, done
-- under two seconds, with nothing you are forced to fill in. Capture inherits
the view you are standing in: type in Today and the task is due today, type
inside a list and it joins that list.

THE VIEWS
Today, Upcoming and Anytime are computed from the dates, never curated.
Overdue tasks belong to Today, because giving them a screen of their own only
means two lists to read before breakfast. Anytime is a real home for
everything with no date, in the order you dragged them into.

WHAT A TASK CAN HAVE
A due date, and optionally a time. One level of subtasks -- enough to break a
job into steps, not enough to build a tree. A note. A list to belong to. A
repeat: daily, weekly, monthly or yearly, which advances to the next
occurrence when you tick it off rather than closing. Defer, to push something
to tomorrow or next week without opening it.

Press and hold a task for its menu: today, tomorrow, done, delete. Drag to
reorder wherever manual order makes sense. Completed tasks are kept on their
own page. Deleting is a real delete, behind the standard remorse timer --
there is no archive and no hidden copy.

YOUR CALENDAR, IF YOU ASK
Each task has two independent switches. One writes the task into your calendar
as an event and keeps it in step: change the day or the time and the old event
goes rather than a second one appearing. The other sets a reminder, which
rides on that event, so it arrives whether or not the app is running. A task
with both switches off never touches your calendar at all.

FIAT COLOURS
The app follows your ambience out of the box. One item in the pull-down menu
switches it to Fiat colours instead: the family's own light paper and plum
accent, the same palette in every Fiat app. The choice is remembered.

WHAT IT IS NOT
Not a project manager. No time tracking, no pomodoro, no kanban board, no
plugins, no shared projects, no sync service. If a feature would only matter
to someone running work across a team, it is not here, and that is the design
rather than a gap.

YOUR DATA
Everything stays on this phone, in one file. There is no account, no network
access, and nothing is measured or reported. The only permission the app asks
for is your calendar, used only for the switches described above.

THE NAME
Latin: agenda, the things that must be done. A plural, from agere, to do.
Fourth in the Fiat family, after fiat lux (a light meter for film), fiat vox
(a chromatic tuner) and fiat mos (a habit tracker). Every name translates
itself.

%if 0%{?_chum}
Title: fiat agenda
Type: desktop-application
DeveloperName: Munkstolen
Categories:
 - Utility
 - Office
AIRating: V
AINote: Claude is my typist - I cross review with Mistral, and add the code once it looks good. Architecture, design, on-device testing, releases and maintenance by me; issues and input welcome.
Custom:
  Repo: https://github.com/munksh/FiatAgenda
PackageIcon: https://munkstolen.se/SFOS/harbour-fiatagenda.png
Screenshots:
 - https://munkstolen.se/SFOS/fiatagenda1.png
 - https://munkstolen.se/SFOS/fiatagenda2.png
 - https://munkstolen.se/SFOS/fiatagenda3.png
Links:
  Homepage: https://github.com/munksh/FiatAgenda
  Bugtracker: https://github.com/munksh/FiatAgenda/issues
%endif

%prep
%setup -q -n %{name}-%{version}

%build
# APP_VERSION is passed through to the .pro, which turns it into a -D for the
# compiler, which hands it to QML as the appVersion context property. The
# about page therefore shows the version this package was BUILT with, and
# Version: above stays the only place the number is written.
%qmake5 APP_VERSION=%{version}
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
make install INSTALL_ROOT=%{buildroot}
desktop-file-install --delete-original \
  --dir %{buildroot}%{_datadir}/applications \
  %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
# The LICENSE is installed by the .pro and listed here by its buildroot path.
# A bare %%license LICENSE does not work under sfdk: rpm runs that step from
# the shadow build directory, which has no LICENSE in it, and the build fails
# on a file that is present in the source tree all along.
%license %{_datadir}/licenses/%{name}/LICENSE
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png

%changelog
* Mon Oct 05 2026 Caesar Prometheus Ivarsson <caesar@munkstolen.se> - 1.2-1
- The About page lists the whole fiat family with full-size icons, and the
  package carries metadata for SailfishOS:Chum: title, icon and screenshots.

