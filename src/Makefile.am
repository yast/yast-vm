#
# Makefile.am for vm/src
#

yncludedir = @yncludedir@/vm

client_DATA =				\
	xen.ycp				\
	vm_source_proposal.ycp		\
	vm_options_proposal.ycp		\
	vm_disks_proposal.ycp		\
	vm_finish.ycp			\
	vm_network_proposal.ycp		\
	inst_vm_source.ycp		\
	inst_vm_options.ycp		\
	inst_vm_disks.ycp		\
	inst_vm_kickoff.ycp		\
	inst_vm_options.ycp		\
	inst_vm_network.ycp		\
	dom0_setup.ycp			\
	vm_network_proposal.ycp

ynclude_DATA = cmdline.ycp

desktop_DATA =				\
	xen.desktop

module_DATA =				\
	VM_XEN.ycp			\
	VM_Common.ycp			\
	VM.ycp

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
