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

# File:	clients/xen.ycp
# Package:	Installation/management in a virtual machine
# Summary:	Main virtual machine installation/management
# Authors:	Michael G. Fritch <mgfritch@novell.com>
#
# $Id: xen.ycp 57028 2009-04-29 10:58:09Z lslezak $
module Yast
  class XenClient < Client
    def main
      #**
      # <h3>Configuration of novell-xad</h3>

      textdomain "vm"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Xen (yast2-vm) module started")


      Yast.import "Arch"
      Yast.import "CommandLine"
      Yast.import "Mode"
      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "Report"
      Yast.import "VM_XEN"

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
      Builtins.y2milestone("Xen (yast-vm) module finished")
      Builtins.y2milestone("----------------------------------------")

      :next 

      # EOF
    end

    # check whether VM can be started
    def CheckConfiguration
      ret = true
      is_s390 = false

      # check whether VM can be started (cannot start a vm using UML)
      return false if VM_XEN.isUML

      # s390 is technical preview and we only fully support x86_64
      if Arch.s390_64 == true
        is_s390 = true
      elsif VM_XEN.isX86_64 == false
        return false
      end

      Builtins.y2milestone("Checking for Xen installation")

      # check the dom0 configuration...
      ret = ret && VM_XEN.ConfigureDom0(is_s390)
      return false if ret == false

      Builtins.y2milestone("CheckConfiguration returned: %1", ret)
      ret
    end
  end
end

Yast::XenClient.new.main
