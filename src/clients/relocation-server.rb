# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006 Novell, Inc. All Rights Reserved.
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

# File:	clients/relocation-server.ycp
# Package:	Configuration of relocation-server
# Summary:	Main file
# Authors:	Li Dongyang <lidongyang@novell.com>
#
# $Id: relocation-server.ycp 27914 2006-02-13 14:32:08Z locilka $
#
# Main file for relocation-server configuration. Uses all other files.
module Yast
  class RelocationServerClient < Client
    def main
      Yast.import "UI"
      Yast.import "FileUtils"

      #**
      # <h3>Configuration of relocation-server</h3>

      textdomain "relocation-server"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("RelocationServer module started")

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Summary"
      Yast.import "VM_XEN"
      Yast.import "Arch"

      Yast.import "CommandLine"
      Yast.include self, "relocation-server/wizards.rb"


      @cmdline_description = {
        "id"         => "relocation-server",
        # Command line help text for the relocation-server module
        "help"       => _(
          "Configuration of relocation-server"
        ),
        "guihandler" => fun_ref(method(:RelocationServerSequence), "any ()"),
        "initialize" => fun_ref(RelocationServer.method(:Read), "boolean ()"),
        "finish"     => fun_ref(RelocationServer.method(:Write), "boolean ()")
      }

      if !Arch.is_kvm && !Arch.is_xen0
        Builtins.y2milestone("No hypervisor found, offer to install one")
        Ops.set(
          @cmdline_description,
          "guihandler",
          fun_ref(method(:CheckConfiguration), "boolean ()")
        )
        Builtins.remove(@cmdline_description, "initialize")
        Builtins.remove(@cmdline_description, "finish")
      end

      # main ui function
      @ret = nil

      @ret = CommandLine.Run(@cmdline_description)
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("RelocationServer module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end

    # check whether VM can be started
    def CheckConfiguration
      ret = true

      # check whether VM can be started (cannot start a vm using UML)
      return false if VM_XEN.isUML

      Builtins.y2milestone("Checking for Xen installation")

      # check the dom0 configuration...
      ret = ret && VM_XEN.ConfigureDom0(Arch.s390_64)
      return false if ret == false

      Builtins.y2milestone("CheckConfiguration returned: %1", ret)
      ret
    end
  end
end

Yast::RelocationServerClient.new.main
