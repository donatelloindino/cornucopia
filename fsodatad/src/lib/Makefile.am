include $(top_srcdir)/Makefile.decl

NULL =

AM_CFLAGS = \
	-include $(CONFIG_HEADER) \
	-DG_LOG_DOMAIN=\"fsodata.lib\" \
	$(NULL)
AM_VALAFLAGS =


modlibexecdir = $(libdir)/cornucopia/modules/fsodata
modlibexec_LTLIBRARIES = libfsodata.la
libfsodata_la_SOURCES = mbpi.vala
libfsodata_la_VALAFLAGS = \
	--basedir $(top_srcdir) \
	--vapidir $(top_srcdir)/vapi \
	--pkg glib-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg libxml-2.0 \
	--pkg fsoframework-2.0 \
	--pkg config \
	--header fsodata.h \
	--library fsodata-2.0 \
	$(DEBUG_VALAFLAGS) \
	$(NULL)
libfsodata_la_CFLAGS = \
	-I$(top_srcdir) \
	$(FSO_CFLAGS) \
	$(XML_CFLAGS) \
	$(GEE_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(DEBUG_CFLAGS) \
	$(NULL)
libfsodata_la_LIBADD = \
	$(FSO_LIBS) \
	$(XML_LIBS) \
	$(GEE_LIBS) \
	$(GLIB_LIBS) \
	$(NULL)
libfsodata_la_LDFLAGS = -no-undefined -avoid-version

CLEANFILES =
MAINTAINERCLEANFILES = \
	Makefile.in \
	$(NULL)
