# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2018 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:	modules/VirtConfig.ycp
# Package:	VirtConfig configuration - generic module
# Authors:	Ladislav Slezak <lslezak@suse.cz>
#		Michael G. Fritch <mgfritch@novell.com>
#
# $Id$
require "yast"

module Yast
  class VirtConfigClass < Module
    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "vm"
      Yast.import "Arch"
      Yast.import "Message"
      Yast.import "OSRelease"
      Yast.import "Package"
      Yast.import "Progress"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "Bootloader"
      Yast.import "Lan"


      @net_path = "/sys/class/net/"
    end

    def isOpenSuse
      Builtins.y2milestone("Checking to see if this is openSUSE ...")
      distro = OSRelease.ReleaseName
      if distro.include? "openSUSE"
        Builtins.y2milestone("Platform is %1", distro)
        return true
      end
      false
    end
    def isTumbleweed
      Builtins.y2milestone("Checking to see if this is Tumbleweed ...")
      distro = OSRelease.ReleaseName
      if distro.include? "Tumbleweed"
        Builtins.y2milestone("Platform is %1", distro)
        return true
      end
      false
    end
    def isSLES
      Builtins.y2milestone("Checking to see if this is SLES ...")
      distro = OSRelease.ReleaseName
      if distro.include? "SLES"
        Builtins.y2milestone("Platform is %1", distro)
        return true
      else
        return false
      end
      false
    end

    def isPAEKernel
      # check is we're running on 32 bit pae.
      Builtins.y2milestone("Checking for PAE kernel...")
      isPAE = false
      cmd = "uname -r"
      Builtins.y2milestone("Executing: %1", cmd)
      retmap = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Ops.set(
        retmap,
        "stdout",
        Builtins.deletechars(Ops.get_string(retmap, "stdout", ""), "\n\t ")
      ) # remove whitespace
      Builtins.y2milestone("retmap=%1", retmap)
      if Ops.get_string(retmap, "stdout", "") != nil &&
          Ops.get_string(retmap, "stdout", "") != ""
        if Builtins.regexpmatch(
            Ops.get_string(retmap, "stdout", ""),
            ".*xenpae$"
          ) # check for kernel-xenpae
          isPAE = true
        elsif Builtins.regexpmatch(
            Ops.get_string(retmap, "stdout", ""),
            ".*bigsmp$"
          ) # check for kernel-bigsmp
          isPAE = true
        else
          isPAE = false
        end
      end
      Builtins.y2milestone("VirtConfig::isPAEKernel returned: %1", isPAE)
      isPAE
    end

    # Check for TextMode only
    def installGUIComponents(packages)
      inst_gui = true

      Builtins.y2milestone("Checking for TextMode display")

      kvm_index = packages.index("patterns-server-kvm_tools")
      xen_index = packages.index("patterns-server-xen_tools")

      if kvm_index != nil || xen_index != nil
        # The tools patterns install gui components. If in text mode we may not want them
        if Ops.get_boolean(UI.GetDisplayInfo, "TextMode", true) == true
          inst_gui = Popup.YesNo(
            _("Running in text mode. Install graphical components anyway?")
          )
        end
      end
      if inst_gui == false
        # Text Mode Only.
        Builtins.y2milestone("Requested not to install graphical components")
        Builtins.y2milestone("Current package list = %1", packages)
        common_packages = ["libvirt-client", "libvirt-daemon-config-network", "virt-manager-common", "virt-install", "vm-install"]
        add_common = false

        # The tools patterns will pull in graphical components so drop entire pattern if present
        if kvm_index != nil
          packages = Builtins.remove(packages, kvm_index)
          packages = Builtins.add(packages, "libvirt-daemon-qemu")
          add_common = true
        end

        if xen_index != nil
          packages = Builtins.remove(packages, xen_index)
          packages = Builtins.add(packages, "libvirt-daemon-xen")
          add_common = true
        end

        if add_common == true
          packages = packages + common_packages
        end
        Builtins.y2milestone("Non-gui package list = %1", packages)
      end

      return packages
    end

    def reloadApparmor
      if Package.InstalledAll(["apparmor"])
        cmd = "systemctl restart apparmor.service"
        Builtins.y2milestone("Restart apparmor.service: %1", cmd)
        SCR.Execute(path(".target.bash"), cmd)
      end
    end

    def isX86_64
      ret = true

      if Arch.x86_64 == false
        arch = Arch.architecture
        Report.Error(
          Ops.add(
            _(
              "x86_64 is the only supported architecture for hosting virtual machines. Your architecture is "
            ),
            arch
          )
        )
        ret = false
      end

      Builtins.y2milestone("VirtConfig::isX86_64 returned: %1", ret)
      ret
    end

    def isUML
      ret = false

      if Arch.is_uml == true
        # we are already in UML, nested virtual machine is not supported
        Report.Error(
          _(
            "Virtual machine installation cannot be started inside the UML machine.\nStart installation in the host system.\n"
          )
        )
        ret = true
      else
        ret = false
      end

      Builtins.y2milestone("VirtConfig::isUML returned: %1", ret)
      false
    end

    def ConfigureDom0(is_s390)
      progress_stages = [
        # progress stage 1/2
        _("Verify Installed Packages"),
        # progress stage 2/2
        _("Network Bridge Configuration")
      ]

      progress_descriptions = []

      configure_bridge = true
      install_xen = false
      install_kvm = false
      widget_id = nil

      bridge_path = ""

      progress_length = Builtins.size(progress_stages)

      # Headline for management domain installation
      headline = _("Configuring the VM Server (domain 0)")

      # xen domain0 installation help text - 1/4
      help_text = _(
        "<p><big><b>VM Server Configuration</b></big></p><p>Configuration of the VM Server (domain 0) has two parts.</p>"
      ) +
        # xen domain0 installation help text - 2/4
        _(
          "<p>The required packages are installed into the system first. Then the boot loader is switched to GRUB (if not already used) and the Xen section is added to the boot loader menu if it is missing.</p>"
        ) +
        # xen domain0 installation help text - 3/4
        _(
          "<p>GRUB is needed because it supports the multiboot standard required to boot Xen and the Linux kernel.</p>"
        ) +
        # xen domain0 installation help text - 4/4
        _(
          "<p>When the configuration has finished successfully, you can boot the VM Server from the boot loader menu.</p>"
        )

      # error popup
      abortmsg = _("The installation will be aborted.")

      def Information
        widgets = Frame(_("Choose Hypervisor(s) to install"),
                    HBox(
                      VBox(
                        Left(Label(_("Server: Minimal system to get a running Hypervisor"))),
                        Left(Label(_("Tools: Configure, manage and monitor virtual machines"))),
                        Left(Label(_("A disabled checkbox means the Hypervisor item has already been installed"))),
                      ),
                      HSpacing(2),
                    ),
                  )
      end
      def VMButtonBox
        widgetB = ButtonBox(
                    PushButton(Id(:accept), Label.AcceptButton),
                    PushButton(Id(:cancel), Label.CancelButton),
                  )
      end
      def KVMDialog
        widgetKVM = Frame(_("KVM Hypervisor"),
                      HBox(
                        Left(CheckBox(Id(:kvm_server), Opt(:key_F6), _("KVM server"))),
                        Left(CheckBox(Id(:kvm_tools), Opt(:key_F7), _("KVM tools"))),
                      ),
                    )
      end
      def LXCDialog
        widgetLXC = Frame(_("libvirt LXC containers"),
                      HBox(
                        Left(CheckBox(Id(:lxc), Opt(:key_F4), _("libvirt LXC daemon"))),
                      ),
                    )
      end

      # Generate a pop dialog to allow user selection of Xen or KVM
      if is_s390 == true
        UI.OpenDialog(
                      HBox(
                        HSpacing(2),
                        VBox(
                          Information(),
                          VSpacing(1),
                          KVMDialog(),
                          LXCDialog(),
                          VMButtonBox(),
                        ),
                      ),
        )
      else
        UI.OpenDialog(
                      HBox(
                        HSpacing(2),
                        VBox(
                          VSpacing(1),
                          Information(),
                          VSpacing(1),
                          Frame(_("Xen Hypervisor"),
                            HBox(
                              Left(CheckBox(Id(:xen_server), Opt(:key_F8), _("Xen server"))),
                              Left(CheckBox(Id(:xen_tools), Opt(:key_F9), _("Xen tools"))),
                            ),
                          ),
                          KVMDialog(),
                          LXCDialog(),
                          VMButtonBox(),
                        ),
                      ),
        )
      end

      log.info "VirtConfig::ConfigureDom0: Checking for Installed Patterns and Packages"
      UI.ChangeWidget(Id(:xen_server), :Enabled, !Package.Installed("patterns-server-xen_server"))
      UI.ChangeWidget(Id(:xen_tools), :Enabled, !Package.Installed("patterns-server-xen_tools"))
      UI.ChangeWidget(Id(:kvm_server), :Enabled, !Package.Installed("patterns-server-kvm_server"))
      UI.ChangeWidget(Id(:kvm_tools), :Enabled, !Package.Installed("patterns-server-kvm_tools"))

      if Package.Installed("libvirt-daemon-lxc") && Package.Installed("libvirt-daemon-config-network")
        UI.ChangeWidget(Id(:lxc), :Enabled, false)
      end

      widget_id = UI.UserInput
      if widget_id == :accept
          install_xen_server = UI.QueryWidget(Id(:xen_server), :Value)
          install_xen_tools = UI.QueryWidget(Id(:xen_tools), :Value)
          install_kvm_server = UI.QueryWidget(Id(:kvm_server), :Value)
          install_kvm_tools = UI.QueryWidget(Id(:kvm_tools), :Value)
          install_client_tools = UI.QueryWidget(Id(:client_tools), :Value)
          install_lxc = UI.QueryWidget(Id(:lxc), :Value)
      end

      UI.CloseDialog

      install_vm = false
      install_vm = true if install_xen_server
      install_vm = true if install_xen_tools
      install_xen = true if install_xen_server || install_xen_tools
      install_vm = true if install_kvm_server
      install_vm = true if install_kvm_tools
      install_kvm = true if install_kvm_server || install_kvm_tools
      install_vm = true if install_client_tools

      if widget_id == :cancel || !install_vm && !install_lxc
        Builtins.y2milestone(
          "VirtConfig::ConfigureDom0 Cancel Selected or no platform selected."
        )
        return false
      end

      Wizard.OpenNextBackDialog
      Wizard.SetDesktopTitleAndIcon("org.opensuse.yast.VirtualizationConfig")

      # enable progress
      progress = Progress.set(true)

      # Headline for virtual machine installation
      Progress.New(
        headline,
        "",
        progress_length,
        progress_stages,
        progress_descriptions,
        help_text
      )

      # package stage
      Progress.NextStage

      packages = []
      common_vm_packages = []

      result = true
      if install_lxc
        packages = ["libvirt-daemon-lxc", "libvirt-daemon-config-network"]
        result = Package.DoInstall(packages)
        unless result
          Report.Error(Message.FailedToInstallPackages)
          return false
        end
      end

      packages << "patterns-server-xen_server" if install_xen_server
      packages << "patterns-server-xen_tools" if install_xen_tools
      packages << "patterns-server-kvm_server" if install_kvm_server
      packages << "patterns-server-kvm_tools" if install_kvm_tools
      packages = installGUIComponents(packages)
      result = Package.DoInstall(packages)
      unless result
        Report.Error(Message.FailedToInstallPackages)
        return false
      end

      success = true

      # progressbar title - check whether Xen packages are installed
      Progress.Title(_("Checking packages..."))
      if Package.InstalledAll(packages) == false
        # progressbar title - install the required packages
        Progress.Title(_("Installing packages..."))
        success = Package.InstallAll(packages)
        if success == false
          # error popup
          Report.Error(
            Ops.add(_("Cannot install required packages.") + "\n", abortmsg)
          )
          return false
        end
        # Now see if they really were installed (bnc#508347)
        if Package.InstalledAll(packages) == false
          Report.Error(
            Ops.add(_("Cannot install required packages.") + "\n", abortmsg)
          )
          return false
        end
      end

      # If grub2 is the bootloader and we succesfully installed Xen, update the grub2 files
      if install_xen
        Builtins.y2milestone("Checking for bootloader type")
        if Bootloader.getLoaderType == "grub2" || Bootloader.getLoaderType == "grub2-efi"
          Progress.Title(_("Updating grub2 configuration files..."))

          old_progress = Progress.set(false)
          Bootloader.Write
          Progress.set(old_progress)
        end
      end

      if is_s390 == false
        # create a bridget for SLES host
        # Default Bridge stage
        Progress.NextStage

        Progress.Title(_("Configuring Default Network Bridge..."))

        # Check for the existance of /sys/class/net/*/bridge
        interfaces = Convert.convert(
            SCR.Read(path(".target.dir"), @net_path),
            :from => "any",
            :to   => "list <string>"
                                     )
        if NetworkService.is_network_manager
          Builtins.y2milestone("NetworkManager is being used. Bridge configuration must be done manually.")
          configure_bridge = false
        else
          Builtins.foreach(interfaces) do |i|
            Builtins.y2milestone("Checking for bridges...")
            bridge_path = Ops.add(Ops.add(Ops.add(@net_path, "/"), i), "/bridge")
            if Ops.greater_or_equal(SCR.Read(path(".target.dir"), bridge_path), 0)
              Builtins.y2milestone("Dom0 already has a configured bridge.")
              configure_bridge = false
              raise Break
            end
          end
        end

        # Popup yes/no dialog
        if configure_bridge == true
          if Popup.AnyQuestionRichText(
              _("Network Bridge."),
              _(
                "<p>For normal network configurations hosting virtual machines, a network bridge is recommended.</p><p>Configure a default network bridge?</p>"
              ),
              45,
              5,
              Label.YesButton,
              Label.NoButton,
              :focus_yes
            )
            Builtins.y2milestone("Configuring default bridge for Xen or KVM...")
            Lan.Read(:cache)
            Lan.ProposeVirtualized
            Lan.Write
          end
        end
      else
        # For s390, make sure /etc/zipl.conf contain switch_amode
        switch_amode = Bootloader.kernel_param(:common, "switch_amode")
        if switch_amode == :missing
          Builtins.y2milestone(
            "No switch_amode kernel boot parameter in /etc/zipl.conf, adding ..."
          )
          Bootloader.modify_kernel_params(:common, "switch_amode" => :present)
          if Bootloader.Write
            zipl_updated = true
            Builtins.y2milestone(
              "Successful update of /etc/zipl.conf with the switch_amode kernel boot parameter"
            )
          else
            Builtins.y2milestone(
              "Failed to correctly update /etc/zipl.conf with switch_amode kernel boot parameter"
            )
          end
        end
      end

      # Force AppArmor to reload the profiles
      reloadApparmor

      # Enable and start the libvirtd daemon for both KVM and Xen
      cmd = "systemctl enable libvirtd.service"
      Builtins.y2milestone("Enable libvirtd.service: %1", cmd)
      SCR.Execute(path(".target.bash"), cmd)
      cmd = "systemctl start libvirtd.service"
      Builtins.y2milestone("Start libvirtd.service: %1", cmd)
      SCR.Execute(path(".target.bash"), cmd)

      # Enable and start the virtlogd socket (libvirt >= 1.3.0) for both KVM and Xen
      cmd = "systemctl enable virtlogd.socket"
      Builtins.y2milestone("Enable virtlogd.socket: %1", cmd)
      SCR.Execute(path(".target.bash"), cmd)
      cmd = "systemctl start virtlogd.socket"
      Builtins.y2milestone("Start virtlogd.socket: %1", cmd)
      SCR.Execute(path(".target.bash"), cmd)

      Progress.Finish

      message_kvm_ready = _(
        "KVM components are installed. Your host is ready to install KVM guests."
      )
      message_kvm_reboot = _(
        "KVM components are installed. Reboot the machine and select the native kernel in the boot loader menu to install KVM guests."
      )
      message_xen_reboot = _(
        "For installing Xen guests, reboot the machine and select the Xen section in the boot loader menu."
      )
      message_xen_ready = _("Xen Hypervisor and tools are installed.")
      message_client_ready = _("Virtualization client tools are installed.")
      message_lxc_ready = _("Libvirt LXC components are installed.")
      message = ""

      if Arch.is_xen == false
        if install_kvm
          message.concat(message_kvm_ready)
          message.concat("\n\n")
        end
        if install_xen
          message.concat(message_xen_reboot)
          message.concat("\n\n")
        end
      else
        if install_xen
          message.concat(message_xen_ready)
          message.concat("\n\n")
        end
        if install_kvm
          message.concat(message_kvm_reboot)
          message.concat("\n\n")
        end
      end
      if install_client_tools
        message.concat(message_client_ready)
        message.concat("\n\n")
      end
      if install_lxc
        message.concat(message_lxc_ready)
      end
      Popup.LongMessage(message)

      Wizard.CloseDialog

      Builtins.y2milestone("VirtConfig::ConfigureDom0 returned: %1", success)
      success
    end

    publish :function => :isOpenSuse, :type => "boolean ()"
    publish :function => :isPAEKernel, :type => "boolean ()"
    publish :function => :isX86_64, :type => "boolean ()"
    publish :function => :isUML, :type => "boolean ()"
    publish :function => :ConfigureDom0, :type => "boolean (boolean)"
  end

  VirtConfig = VirtConfigClass.new
  VirtConfig.main
end
