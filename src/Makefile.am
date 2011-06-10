#
# Makefile.am for vm/src
#

yncludedir = @yncludedir@/relocation-server

groupdir = @desktopdir@/groups

client_DATA =			\
	vm_finish.ycp		\
	relocation-server.ycp	

ynclude_DATA =          \
		helps.ycp       \
		wizards.ycp     \
		dialogs.ycp     \
		complex.ycp

group_DATA =			\
	virtualization.desktop

desktop_DATA =			\
	relocation-server.desktop

module_DATA =			\
	VM_XEN.ycp			\
	RelocationServer.ycp

EXTRA_DIST = $(client_DATA) $(module_DATA) $(group_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
