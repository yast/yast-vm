# Sources for vm

module_DATA = \
  modules/RelocationServer.rb \
  modules/VirtConfig.rb

client_DATA = \
  clients/virtualization.rb \
  clients/vm_finish.rb \
  clients/relocation-server.rb

yncludedir = @yncludedir@/relocation-server
ynclude_DATA = \
  include/relocation-server/wizards.rb \
  include/relocation-server/dialogs.rb \
  include/relocation-server/complex.rb \
  include/relocation-server/helps.rb

scrconf_DATA = \
  scrconf/xend.scr

desktop_DATA = \
  desktop/relocation-server.desktop \
  desktop/virtualization-config.desktop

desktop1dir = @desktopdir@/groups
desktop1_DATA = \
  desktop/groups/virtualization.desktop

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(desktop_DATA) $(desktop1_DATA)

include $(top_srcdir)/Makefile.am.common
