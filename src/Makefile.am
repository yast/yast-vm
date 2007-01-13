#
# Makefile.am for vm/src
#

yncludedir = @yncludedir@/vm

client_DATA =				\
	xen.ycp				\
	vm_finish.ycp			\
	dom0_setup.ycp

desktop_DATA =				\
	xen.desktop

module_DATA =				\
	VM_XEN.ycp			\
	VM_Common.ycp			\
	VM.ycp

EXTRA_DIST = $(client_DATA) $(module_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
