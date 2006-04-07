#
# Makefile.am for vm/src
#

yncludedir = @yncludedir@/vm

client_DATA =				\
	xen.ycp				\
	vm_helps_proposal.ycp		\
	vm_autoyast_proposal.ycp	\
	vm_source_proposal.ycp		\
	vm_options_proposal.ycp		\
	vm_hardware_proposal.ycp	\
	vm_disks_proposal.ycp		\
	vm_finish.ycp			\
	vm_network_proposal.ycp		\
	xen_mode_proposal.ycp		\
	inst_vm_autoyast.ycp		\
	inst_vm_source.ycp		\
	inst_vm_options.ycp		\
	inst_vm_hardware.ycp		\
	inst_vm_disks.ycp		\
	inst_vm_kickoff.ycp		\
	inst_vm_options.ycp		\
	inst_vm_network.ycp		\
	inst_xen_mode.ycp		\
	inst_xen_create.ycp		\
	inst_vm_manage.ycp		\
	dom0_setup.ycp			\
	vm_network_proposal.ycp		\
	xen_auto.ycp

ynclude_DATA = cmdline.ycp

desktop_DATA =				\
	xen.desktop

module_DATA =				\
	VM_XEN.ycp			\
	VM_Common.ycp			\
	VM.ycp

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
