include $(top_srcdir)/Makefile.decl

dbusconfdir = @DBUS_DIR@/system.d
dist_dbusconf_DATA = fsodeviced.conf

dbusservicedir = @DBUS_SERVICE_DIR@/../system-services
dbusservice_in_file = org.freesmartphone.odeviced.service.in
dist_dbusservice_DATA = $(dbusservice_in_file:.service.in=.service)

EXTRA_DIST += fsodeviced.service

CLEANFILES = $(dist_dbusservice_DATA)
MAINTAINERCLEANFILES = Makefile.in

