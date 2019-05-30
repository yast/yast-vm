# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2007 Novell, Inc. All Rights Reserved.
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

# File:	clients/virtualization.ycp
# Package:	Installation/management in a virtual machine
# Summary:	Main virtual machine installation/management
# Authors:	Michael G. Fritch <mgfritch@novell.com>
#
# $Id: virtualization.ycp 57028 2009-04-29 10:58:09Z lslezak $
module Yast
  class VirtualizationClient < Client
    def main
      #**
      # <h3>Configuration of novell-xad</h3>

      textdomain "vm"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Virtualization (yast2-vm) module started")


      Yast.import "Arch"
      Yast.import "CommandLine"
      Yast.import "Mode"
      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "VirtConfig"

      # Main

      # Definition of command line mode options
      @cmdline = {
        "id"         => "vm",
        "help"       => _("Install Hypervisor and Tools"),
        "guihandler" => fun_ref(method(:CheckConfiguration), "boolean ()")
      }


      @rc = CommandLine.Run(@cmdline)
      Builtins.y2milestone("YAST2-VM: rc = %1", @rc)

      # Always check the dom0 configuration
      #    boolean ret = CheckConfiguration();
      #    if (ret == false) return `abort;

      # Finish
      Builtins.y2milestone("Virtualization (yast-vm) module finished")
      Builtins.y2milestone("----------------------------------------")

      :next 

      # EOF
    end

    # check whether VM can be started
    def CheckConfiguration
      ret = true

      # check whether VM can be started (cannot start a vm using UML)
      return false if VirtConfig.isUML

      # s390, aarch64 and ppc64 are technical preview
      is_preview = Arch.s390_64 || Arch.aarch64 || Arch.ppc64
      return false unless is_preview || VirtConfig.isX86_64

      Builtins.y2milestone("Checking for Virtualization installation")

      # check the dom0 configuration...
      ret = ret && VirtConfig.ConfigureDom0()
      return false if ret == false

      Builtins.y2milestone("CheckConfiguration returned: %1", ret)
      ret
    end
  end
end

Yast::VirtualizationClient.new.main
