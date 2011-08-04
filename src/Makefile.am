#
# Makefile.am for vm/src
#

yncludedir = @yncludedir@/relocation-server

groupdir = @desktopdir@/groups

client_DATA =			\
	xen.ycp			\
	vm_finish.ycp		\
	relocation-server.ycp	

group_DATA =			\
	virtualization.desktop

desktop_DATA =			\
	xen.desktop		\
	relocation-server.desktop

module_DATA =			\
	VM_XEN.ycp		\
	RelocationServer.ycp

ynclude_DATA =			\
	helps.ycp		\
	wizards.ycp		\
	dialogs.ycp		\
	complex.ycp


EXTRA_DIST = $(client_DATA) $(module_DATA) $(group_DATA) $(desktop_DATA) $(ynclude_DATA)

relocation-server:
	test -l relocation-server || ln -s . relocation-server

ycpchook = relocation-server

include $(top_srcdir)/Makefile.am.common
