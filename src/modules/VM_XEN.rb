# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2013 Novell, Inc. All Rights Reserved.
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

# File:	modules/VM_XEN.ycp
# Package:	VM_XEN configuration - generic module
# Authors:	Ladislav Slezak <lslezak@suse.cz>
#		Michael G. Fritch <mgfritch@novell.com>
#
# $Id$
require "yast"

module Yast
  class VM_XENClass < Module
    def main
      Yast.import "UI"

      textdomain "vm"


      Yast.import "Arch"
      Yast.import "OSRelease"
      Yast.import "Package"
      Yast.import "Progress"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "SuSEFirewall"
      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "Bootloader"


      @net_path = "/sys/class/net/"
    end

    def ConfigureFirewall
      Builtins.y2milestone("VM_XEN::ConfigureFirewall() started")
      ret = true

      # check whether the firewall option exists
      firewall_configured = false
      if Builtins.contains(
          SCR.Dir(path(".sysconfig.SuSEfirewall2")),
          "FW_FORWARD_ALWAYS_INOUT_DEV"
        )
        xen_bridge = "xenbr+"
        # read the current value
        forward = Convert.to_string(
          SCR.Read(path(".sysconfig.SuSEfirewall2.FW_FORWARD_ALWAYS_INOUT_DEV"))
        )
        Builtins.y2milestone("FW_FORWARD_ALWAYS_INOUT_DEV=%1", forward)
        if Builtins.contains(Builtins.splitstring(forward, " "), xen_bridge)
          Builtins.y2milestone("Firewall already configured!")
          firewall_configured = true # xenbr+ already exists
        end
      end

      if firewall_configured == false
        # add xenbr+ to the firewall configuration
        Builtins.y2milestone("Configuring firewall to allow Xen bridge...")
        progress_orig = Progress.set(false)
        SuSEFirewall.Read
        SuSEFirewall.AddXenSupport
        ret = ret && SuSEFirewall.Write
        Progress.set(progress_orig)
      end

      Builtins.y2milestone("VM_XEN::ConfigureFirewall returned: %1", ret)
      ret
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
      Builtins.y2milestone("VM_XEN::isPAEKernel returned: %1", isPAE)
      isPAE
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

      Builtins.y2milestone("VM_XEN::isX86_64 returned: %1", ret)
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

      Builtins.y2milestone("VM_XEN::isUML returned: %1", ret)
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

      bridge_exists = false
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

      # Generate a pop dialog to allow user selection of Xen or KVM
      if is_s390 == true
        UI.OpenDialog(
          VBox(
            Label(_("Select the virtualization platform to install.")),
            Left(CheckBox(Id(:xen), Opt(:disabled), "Xen")),
            Left(CheckBox(Id(:kvm), "KVM")),
            ButtonBox(
              PushButton(Id(:accept), Label.AcceptButton),
              PushButton(Id(:cancel), Label.CancelButton)
            )
          )
        )
      else
        UI.OpenDialog(
          VBox(
            Label(_("Select the virtualization platform to install.")),
            Left(CheckBox(Id(:xen), "Xen")),
            Left(CheckBox(Id(:kvm), "KVM")),
            ButtonBox(
              PushButton(Id(:accept), Label.AcceptButton),
              PushButton(Id(:cancel), Label.CancelButton)
            )
          )
        )
      end

      widget_id = UI.UserInput
      if widget_id == :accept
        install_xen = Convert.to_boolean(UI.QueryWidget(Id(:xen), :Value))
        install_kvm = Convert.to_boolean(UI.QueryWidget(Id(:kvm), :Value))
      end

      UI.CloseDialog

      if widget_id == :cancel || install_xen == false && install_kvm == false
        Builtins.y2milestone(
          "VM_XEN::ConfigureDom0 Cancel Selected or no platform selected."
        )
        return false
      end

      Wizard.OpenNextBackDialog
      Wizard.SetDesktopTitleAndIcon("xen")

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

      # Common packages to both Xen and KVM
      packages = ["libvirt-python", "vm-install"]

      if install_xen
        packages = Builtins.add(packages, "libvirt-daemon-xen")
        packages = Builtins.add(packages, "xen")
        packages = Builtins.add(packages, "xen-libs")
        packages = Builtins.add(packages, "xen-tools")
        packages = Builtins.add(packages, "kernel-xen")
      end
      if install_kvm
        packages = Builtins.add(packages, "libvirt-daemon-qemu")
        packages = Builtins.add(packages, "qemu-kvm")
      end

      inst_gui = true

      Builtins.y2milestone("VM_XEN::ConfigureDom0 Checking for packages...")

      # Assume python gtk is installed. If in text mode we don't care
      if Ops.get_boolean(UI.GetDisplayInfo, "TextMode", true) == true
        inst_gui = Popup.YesNo(
          _("Running in text mode. Install graphical components anyway?")
        )
      end
      if inst_gui == true
        packages = Builtins.add(packages, "python-gtk")
        # Also make sure virt-manager and virt-viewer is there - runs GUI only
        packages = Builtins.add(packages, "virt-manager")
        packages = Builtins.add(packages, "virt-viewer")
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
        if Bootloader.getLoaderType == "grub2"
          Progress.Title(_("Updating grub2 configuration files..."))
          cmd = "/usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg"
          Builtins.y2milestone("Executing: %1", cmd)
          SCR.Execute(path(".target.bash"), cmd)
        end
      end

      if is_s390 == false
        # Default Bridge stage
        Progress.NextStage

        Progress.Title(_("Configuring Default Network Bridge..."))

        # Check for the existance of /sys/class/net/*/bridge
        interfaces = Convert.convert(
          SCR.Read(path(".target.dir"), @net_path),
          :from => "any",
          :to   => "list <string>"
        )
        Builtins.foreach(interfaces) do |i|
          Builtins.y2milestone("Checking for bridges...")
          bridge_path = Ops.add(Ops.add(Ops.add(@net_path, "/"), i), "/bridge")
          if Ops.greater_or_equal(SCR.Read(path(".target.dir"), bridge_path), 0)
            Builtins.y2milestone("Dom0 already has a configured bridge.")
            bridge_exists = true
            raise Break
          end
        end

        # Popup yes/no dialog
        if bridge_exists == false
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
            WFM.call("lan_proposal", ["MakeProposal"])
            UI.OpenDialog(VBox())
            WFM.call("lan_proposal", ["Write"])
            UI.CloseDialog
          end
        end

        # Enable the libvirtd daemon if openSUSE
        if isOpenSuse == true
          cmd = "systemctl enable libvirtd.service"
          Builtins.y2milestone("Executing: %1", cmd)
          SCR.Execute(path(".target.bash"), cmd)
        end
      else
        # For s390, make sure /etc/zipl.conf contain switch_amode
        def_section = Bootloader.getDefaultSection
        switch_amode = Bootloader.getKernelParam(def_section, "switch_amode")
        if switch_amode == "false"
          zipl_updated = false
          Builtins.y2milestone(
            "No switch_amode kernel boot parameter in /etc/zipl.conf, adding ..."
          )
          if Bootloader.setKernelParam(def_section, "switch_amode", "true") == true
            if Bootloader.Write == true
              zipl_updated = true
              cmd = "/sbin/zipl"
              Builtins.y2milestone("Executing: %1", cmd)
              SCR.Execute(path(".target.bash"), cmd)
              Builtins.y2milestone(
                "Successful update of /etc/zipl.conf with the switch_amode kernel boot parameter"
              )
            end
          end
          if zipl_updated == false
            Builtins.y2milestone(
              "Failed to correctly update /etc/zipl.conf with switch_amode kernel boot parameter"
            )
          end
        end
      end

      # Firewall stage - modify the firewall setting, add the xen bridge to FW_FORWARD_ALWAYS_INOUT_DEV
      # Progress::NextStage();

      # Configure firewall to allow xenbr+
      # success = success && ConfigureFirewall();
      # if ( success == false ) {
      #     // error popup
      #     Report::Error(_("Failed to configure the firewall to allow the Xen bridge") + "\n" + abortmsg);
      #     return false;
      # }

      Progress.Finish

      message_kvm_ready = _(
        "KVM components are installed. Your host is ready to install KVM guests."
      )
      message_kvm_reboot = _(
        "KVM components are installed. Reboot the machine and select the native kernel in the boot loader menu to install KVM guests."
      )
      message_xen_reboot = _(
        "For installing Xen guests, reboot the machine and select the Xen section in the boot loader menu.\n"
      )
      message_xen_ready = _("Xen Hypervisor and tools are installed.")
      message = nil

      if install_xen == false
        if Arch.is_xen == false
          Popup.LongMessage(message_kvm_ready)
        else
          Popup.LongMessage(message_kvm_reboot)
        end
      else
        if Arch.is_xen == false
          if install_kvm == true
            message = Builtins.sformat(
              "%1\n\n%2",
              message_kvm_ready,
              message_xen_reboot
            )
          else
            message = message_xen_reboot
          end
          # popup message - ask user to reboot the machine
          Popup.LongMessage(message)
        else
          # popup message - Notify user of successful completion (or already installed).
          if install_kvm == true
            message = Builtins.sformat(
              "%1\n\n%2",
              message_kvm_reboot,
              message_xen_ready
            )
          else
            message = message_xen_ready
          end
          Popup.Message(message)
        end
      end

      Wizard.CloseDialog

      Builtins.y2milestone("VM_XEN::ConfigureDom0 returned: %1", success)
      success
    end

    publish :function => :ConfigureFirewall, :type => "boolean ()"
    publish :function => :isOpenSuse, :type => "boolean ()"
    publish :function => :isPAEKernel, :type => "boolean ()"
    publish :function => :isX86_64, :type => "boolean ()"
    publish :function => :isUML, :type => "boolean ()"
    publish :function => :ConfigureDom0, :type => "boolean (boolean)"
  end

  VM_XEN = VM_XENClass.new
  VM_XEN.main
end
