include $(top_srcdir)/Makefile.decl

NULL =

INCLUDES = \
	$(FSO_CFLAGS) \
	$(GLIB_CFLAGS) \
	-include $(CONFIG_HEADER) \
	-DG_LOG_DOMAIN=\"fsoevents\" \
	$(NULL)

BUILT_SOURCES = .vala.stamp

sbin_PROGRAMS = fsoeventsd

fsoeventsd_VALASOURCES = \
	main.vala \
	$(NULL)

fsoeventsd_SOURCES = \
	$(fsoeventsd_VALASOURCES:.vala=.c) \
	$(NULL)

$(BUILT_SOURCES): $(fsoeventsd_VALASOURCES)
	$(VALAC) -C --vapidir $(top_srcdir)/vapi \
				--pkg posix \
				--pkg config \
				--pkg gio-2.0 \
				--pkg fsoframework-2.0 \
				--save-temps \
				--basedir $(top_srcdir) $^
	touch $@

fsoeventsd_LDADD = \
	$(FSO_LIBS) \
	$(GLIB_LIBS) \
	$(NULL)

EXTRA_DIST += \
	$(fsoeventsd_VALASOURCES) \
	$(BUILT_SOURCES) \
	$(NULL)

CLEANFILES = \
	*.c \
	*.h \
	$(BUILT_SOURCES) \
	$(NULL)

MAINTAINERCLEANFILES = \
	Makefile.in \
	$(NULL)
