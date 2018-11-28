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

scalabledir = @icondir@/hicolor/scalable/apps
scalable_DATA = \
  icons/hicolor/scalable/apps/yast-vm-install.svg \
  icons/hicolor/scalable/apps/yast-vm-migrate.svg

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(desktop_DATA) $(scalable_DATA)

include $(top_srcdir)/Makefile.am.common
