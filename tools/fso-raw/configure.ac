AC_INIT([fso-raw], [1.0.0], [smartphones-userland@linuxtogo.org], [fso-raw])
AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_HEADERS(config.h)
AM_INIT_AUTOMAKE([dist-bzip2])

AC_PROG_CC
AM_PROG_CC_C_O
AC_GNU_SOURCE
AC_DISABLE_STATIC
AC_PROG_LIBTOOL

VALA_REQUIRED=0.16.0
AC_PATH_PROG(VALAC, valac, valac)
AC_SUBST(VALAC)
m4_ifdef([AM_PROG_VALAC], [AM_PROG_VALAC([$VALA_REQUIRED])])

AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(LDFLAGS)

GLIB_REQUIRED=2.26.0

# glib and friends
PKG_CHECK_MODULES(GLIB,
  glib-2.0 >= $GLIB_REQUIRED
  gobject-2.0 >= $GLIB_REQUIRED
  gio-2.0 >= $GLIB_REQUIRED)
AC_SUBST(GLIB_CFLAGS)
AC_SUBST(GLIB_LIBS)

AC_ARG_ENABLE(debug,
  [  --enable-debug            Enable debug build (default=disabled)],
  [enable_debug=$enableval],
  [enable_debug="no"])
AM_CONDITIONAL( [WANT_DEBUG], [test x"$enable_debug" = x"yes"])

AC_CONFIG_FILES([
  Makefile
  src/Makefile
])

AC_OUTPUT
