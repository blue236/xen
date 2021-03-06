#  -*- mode: Makefile; -*-

# `all' is the default target
all:

-include $(XEN_ROOT)/config/Tools.mk
include $(XEN_ROOT)/Config.mk

export _INSTALL := $(INSTALL)
INSTALL = $(XEN_ROOT)/tools/cross-install

XEN_INCLUDE        = $(XEN_ROOT)/tools/include
XEN_LIBXC          = $(XEN_ROOT)/tools/libxc
XEN_XENLIGHT       = $(XEN_ROOT)/tools/libxl
XEN_XENSTORE       = $(XEN_ROOT)/tools/xenstore
XEN_LIBXENSTAT     = $(XEN_ROOT)/tools/xenstat/libxenstat/src
XEN_BLKTAP2        = $(XEN_ROOT)/tools/blktap2
XEN_LIBVCHAN       = $(XEN_ROOT)/tools/libvchan

CFLAGS_xeninclude = -I$(XEN_INCLUDE)

XENSTORE_XENSTORED ?= y

ifneq ($(nosharedlibs),y)
INSTALL_SHLIB = $(INSTALL_PROG)
SYMLINK_SHLIB = ln -sf
libextension = .so
else
libextension = .a
XENSTORE_STATIC_CLIENTS=y
# If something tries to use these it is a mistake.  Provide references
# to nonexistent programs to produce a sane error message.
INSTALL_SHLIB = : install-shlib-unsupported-fail
SYMLINK_SHLIB = : symlink-shlib-unsupported-fail
endif

# Compiling and linking against in tree libraries.
#
# In order to compile and link against an in-tree library various
# cpp/compiler/linker options are required.
#
# For example consider a library "libfoo" which itself uses two other
# libraries:
#  libbar - whose use is entirely internal to libfoo and not exposed
#           to users of libfoo at all.
#  libbaz - whose use is entirely internal to libfoo but libfoo's
#           public headers include one or more of libbaz's
#           public headers. Users of libfoo are therefore transitively
#           using libbaz's header but not linking against libbaz.
#
# SHDEPS_libfoo: Flags for linking recursive dependencies of
#                libfoo. Must contain SHLIB for every library which
#                libfoo links against. So must contain both
#                $(SHLIB_libbar) and $(SHLIB_libbaz).
#
# SHLIB_libfoo: Flags for recursively linking against libfoo. Must
#               contains SHDEPS_libfoo and:
#                   -Wl,-rpath-link=<directory containing libfoo.so>
#
# CFLAGS_libfoo: Flags for compiling against libfoo. Must add the
#                directories containing libfoo's headers to the
#                include path. Must recursively include
#                $(CFLAGS_libbaz), to satisfy the transitive inclusion
#                of the headers but not $(CFLAGS_libbar) since none of
#                libbar's headers are required to build against
#                libfoo.
#
# LDLIBS_libfoo: Flags for linking against libfoo. Must contain
#                $(SHDEPS_libfoo) and the path to libfoo.so
#
# Consumers of libfoo should include $(CFLAGS_libfoo) and
# $(LDLIBS_libfoo) in their appropriate directories. They should not
# include any CFLAGS or LDLIBS relating to libbar or libbaz unless
# they use those libraries directly (not via libfoo) too.
#
# Consumers of libfoo should not directly use $(SHDEPS_libfoo) or
# $(SHLIB_libfoo)

CFLAGS_libxenctrl = -I$(XEN_LIBXC)/include $(CFLAGS_xeninclude)
SHDEPS_libxenctrl =
LDLIBS_libxenctrl = $(XEN_LIBXC)/libxenctrl$(libextension)
SHLIB_libxenctrl  = -Wl,-rpath-link=$(XEN_LIBXC)

CFLAGS_libxenguest = -I$(XEN_LIBXC)/include $(CFLAGS_xeninclude)
SHDEPS_libxenguest =
LDLIBS_libxenguest = $(SHDEPS_libxenguest) $(XEN_LIBXC)/libxenguest$(libextension)
SHLIB_libxenguest  = $(SHDEPS_libxenguest) -Wl,-rpath-link=$(XEN_LIBXC)

CFLAGS_libxenstore = -I$(XEN_XENSTORE)/include $(CFLAGS_xeninclude)
SHDEPS_libxenstore =
LDLIBS_libxenstore = $(SHDEPS_libxenguest) $(XEN_XENSTORE)/libxenstore$(libextension)
SHLIB_libxenstore  = $(SHDEPS_libxenguest) -Wl,-rpath-link=$(XEN_XENSTORE)

CFLAGS_libxenstat  = -I$(XEN_LIBXENSTAT)
SHDEPS_libxenstat  = $(SHLIB_libxenctrl) $(SHLIB_libxenstore)
LDLIBS_libxenstat  = $(SHDEPS_libxenstat) $(XEN_LIBXENSTAT)/libxenstat$(libextension)
SHLIB_libxenstat   = $(SHDEPS_libxenstat) -Wl,-rpath-link=$(XEN_LIBXENSTAT)

CFLAGS_libxenvchan = -I$(XEN_LIBVCHAN)
SHDEPS_libxenvchan = $(SHLIB_libxenctrl) $(SHLIB_libxenstore)
LDLIBS_libxenvchan = $(SHDEPS_libxenvchan) $(XEN_LIBVCHAN)/libxenvchan$(libextension)
SHLIB_libxenvchan  = $(SHDEPS_libxenvchan) -Wl,-rpath-link=$(XEN_LIBVCHAN)

ifeq ($(debug),y)
# Disable optimizations and enable debugging information for macros
CFLAGS += -O0 -g3
# But allow an override to -O0 in case Python enforces -D_FORTIFY_SOURCE=<n>.
PY_CFLAGS += $(PY_NOOPT_CFLAGS)
endif

LIBXL_BLKTAP ?= $(CONFIG_BLKTAP2)

ifeq ($(LIBXL_BLKTAP),y)
CFLAGS_libblktapctl = -I$(XEN_BLKTAP2)/control -I$(XEN_BLKTAP2)/include $(CFLAGS_xeninclude)
SHDEPS_libblktapctl =
LDLIBS_libblktapctl = $(SHDEPS_libblktapctl) $(XEN_BLKTAP2)/control/libblktapctl$(libextension)
SHLIB_libblktapctl  = $(SHDEPS_libblktapctl) -Wl,-rpath-link=$(XEN_BLKTAP2)/control
else
CFLAGS_libblktapctl =
SHDEPS_libblktapctl =
LDLIBS_libblktapctl =
SHLIB_libblktapctl  =
endif

CFLAGS_libxenlight = -I$(XEN_XENLIGHT) $(CFLAGS_libxenctrl) $(CFLAGS_xeninclude)
SHDEPS_libxenlight = $(SHLIB_libxenctrl) $(SHLIB_libxenstore) $(SHLIB_libblktapctl)
LDLIBS_libxenlight = $(SHDEPS_libxenlight) $(XEN_XENLIGHT)/libxenlight$(libextension)
SHLIB_libxenlight  = $(SHDEPS_libxenlight) -Wl,-rpath-link=$(XEN_XENLIGHT)

CFLAGS += -D__XEN_TOOLS__

# Get gcc to generate the dependencies for us.
CFLAGS += -MMD -MF .$(if $(filter-out .,$(@D)),$(subst /,@,$(@D))@)$(@F).d
DEPS = .*.d

ifneq ($(FILE_OFFSET_BITS),)
CFLAGS  += -D_FILE_OFFSET_BITS=$(FILE_OFFSET_BITS)
endif
ifneq ($(XEN_OS),NetBSD)
# Enable implicit LFS support *and* explicit LFS names.
CFLAGS  += -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE
endif

# 32-bit x86 does not perform well with -ve segment accesses on Xen.
CFLAGS-$(CONFIG_X86_32) += $(call cc-option,$(CC),-mno-tls-direct-seg-refs)
CFLAGS += $(CFLAGS-y)

CFLAGS += $(EXTRA_CFLAGS_XEN_TOOLS)

INSTALL_PYTHON_PROG = \
	$(XEN_ROOT)/tools/python/install-wrap "$(PYTHON_PATH)" $(INSTALL_PROG)

%.opic: %.c
	$(CC) $(CPPFLAGS) -DPIC $(CFLAGS) $(CFLAGS_$*.opic) -fPIC -c -o $@ $< $(APPEND_CFLAGS)

%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(CFLAGS_$*.o) -c -o $@ $< $(APPEND_CFLAGS)

%.o: %.cc
	$(CC) $(CPPFLAGS) $(CXXFLAGS) $(CXXFLAGS_$*.o) -c -o $@ $< $(APPEND_CFLAGS)

%.o: %.S
	$(CC) $(CFLAGS) $(CFLAGS_$*.o) -c $< -o $@ $(APPEND_CFLAGS)
%.opic: %.S
	$(CC) $(CPPFLAGS) -DPIC $(CFLAGS) $(CFLAGS.opic) -fPIC -c -o $@ $< $(APPEND_CFLAGS)

subdirs-all subdirs-clean subdirs-install subdirs-distclean: .phony
	@set -e; for subdir in $(SUBDIRS) $(SUBDIRS-y); do \
		$(MAKE) subdir-$(patsubst subdirs-%,%,$@)-$$subdir; \
	done

subdir-all-% subdir-clean-% subdir-install-%: .phony
	$(MAKE) -C $* $(patsubst subdir-%-$*,%,$@)

subdir-distclean-%: .phony
	$(MAKE) -C $* distclean

ifeq (,$(findstring clean,$(MAKECMDGOALS)))
$(XEN_ROOT)/config/Tools.mk:
	$(error You have to run ./configure before building or installing the tools)
endif
