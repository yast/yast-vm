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

# File:
#  vm_finish.ycp
#
# Module:
#  Step of base installation finish
#
# Authors:
#  Ladislav Slezak <lslezak@suse.cz>
#
# $Id$
#
module Yast
  class VmFinishClient < Client
    def main

      textdomain "vm"

      Yast.import "Arch"
      Yast.import "Report"
      Yast.import "FileUtils"
      Yast.import "Service"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      Builtins.y2milestone("starting vm_finish")
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      if @func == "Info"
        # return nil when the system is not Xen domainU,
        # no change is allowed
        if Arch.is_xenU
          Builtins.y2milestone("Detected Xen DomainU")
          @ret = {
            "steps" => 1,
            # progress step title
            "title" => _(
              "Configuring the virtual machine..."
            ),
            "when"  => [:installation, :update, :autoinst]
          }
        else
          Builtins.y2milestone(
            "Xen DomainU not detected, skipping domain configuration"
          )
          @ret = {}
        end
      elsif @func == "Write"
        # be sure that we are in Xen domU
        if Arch.is_xenU
          # disable HW services - they are useless and usually failing in a virtual machine
          @disable_services = ["acpid"]

          @disable_services.each { |s| Service.Disable(s) }

          # Allow a console in addition to VNC with the PV framebuffer
          Builtins.y2milestone("check for xvc0 in securetty")
          SCR.Execute(
            path(".target.bash"),
            "/usr/bin/grep -q xvc0 /etc/securetty || echo xvc0 >> /etc/securetty"
          )

          # Although console appears to be a tty, do not do character translations
          SCR.Execute(
            path(".target.bash"),
            "/bin/sed -i 's/^CONSOLE_MAGIC=.*$/CONSOLE_MAGIC=\"\"/' /etc/sysconfig/console"
          )
        end
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = nil
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("vm_finish finished")
      deep_copy(@ret)
    end
  end
end

Yast::VmFinishClient.new.main
