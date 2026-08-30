Name:       harbour-fiatagenda
Summary:    A fast, minimal task list
Version:    1.0.0
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
Buy milk. Call the dentist before Friday. Water the plants every Sunday, for
as long as there are plants.

Most task apps want to know the project, the tag and the priority before they
will let you write anything down. Fiat Agenda asks for the words. A date is
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
Fourth in the Fiat family, after Fiat Lux (a light meter for film), Fiat Vox
(a chromatic tuner) and Fiat Mos (a habit tracker). Every name translates
itself.

%if 0%{?_chum}
Title: Fiat Agenda
Type: desktop-application
DeveloperName: Munkstolen
Categories:
 - Utility
 - Office
Custom:
  Repo: https://github.com/munksh/FiatAgenda
PackageIcon: https://munkstolen.se/SFOS/fiat-agenda/harbour-fiatagenda.png
Screenshots:
 - https://munkstolen.se/SFOS/fiat-agenda/fiat-agenda1.png
 - https://munkstolen.se/SFOS/fiat-agenda/fiat-agenda2.png
 - https://munkstolen.se/SFOS/fiat-agenda/fiat-agenda3.png
Links:
  Homepage: https://github.com/munksh/FiatAgenda
  Bugtracker: https://github.com/munksh/FiatAgenda/issues
%endif

%prep
%setup -q -n %{name}-%{version}

%build
# APP_VERSION is passed through to the .pro, which turns it into a -D for the
# compiler, which hands it to QML as the `appVersion` context property. The
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
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
