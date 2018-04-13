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

# File:	modules/RelocationServer.ycp
# Package:	Configuration of relocation-server
# Summary:	RelocationServer settings, input and output functions
# Authors:	Li Dongyang <lidongyang@novell.com>
#
# $Id: RelocationServer.ycp 41350 2007-10-10 16:59:00Z dfiser $
#
# Representation of the configuration of relocation-server.
# Input and output routines.
require "yast"

module Yast
  class RelocationServerClass < Module
    def main
      Yast.import "UI"
      textdomain "relocation-server"

      Yast.import "Arch"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Popup"
      Yast.import "Summary"
      Yast.import "Message"
      Yast.import "Service"
      Yast.import "FileUtils"
      Yast.import "SuSEFirewall"
      Yast.import "SuSEFirewallServices"

      # Data was modified?
      @modified = false

      @libvirtd_default_ports = "49152:49215"
      @libvirtd_ports = []

      @libvirtd_enabled = false
      @sshd_enabled = false
      @libvirtd_is_running = false
      @sshd_is_running = false

      @LibvirtdOptions = {
        "tunneled_migration" => false,
        "plain_migration"    => false,
        "default_port_range" => false
      }
    end

    # Returns whether the configuration has been modified.
    def GetModified
      @modified
    end

    # Sets that the configuration has been modified.
    def SetModified
      @modified = true

      nil
    end

    #   Returns a confirmation popup dialog whether user wants to really abort.
    def Abort
      Popup.ReallyAbort(GetModified())
    end

    # Checks whether an Abort button has been pressed.
    # If so, calls function to confirm the abort call.
    #
    # @return [Boolean] true if abort confirmed
    def PollAbort
      return Abort() if UI.PollInput == :abort

      false
    end

    def GetLibVirtdPorts
      deep_copy(@libvirtd_ports)
    end

    def SetLibvirtdPorts(ports)
      ports = deep_copy(ports)
      @libvirtd_ports = deep_copy(ports)

      nil
    end

    def GetLibvirtdOption(key)
      Ops.get(@LibvirtdOptions, key, false)
    end

    def SetLibvirtdOption(key, val)
      Ops.set(@LibvirtdOptions, key, val)

      nil
    end

    def ReadLibvirtServices
      if !Package.Installed("libvirt-daemon")
        Builtins.y2milestone("libvirt is not installed")
        return false
      end
      @libvirtd_enabled = Service.Enabled("libvirtd")
      @sshd_enabled = Service.Enabled("sshd")

      if Service.active?("libvirtd")
        @libvirtd_is_running = true
        Builtins.y2milestone("libvirtd is running")
      else
        @libvirtd_is_running = false
        Builtins.y2milestone("libvirtd is not running")
      end
      if Service.active?("sshd")
        @sshd_is_running = true
        Builtins.y2milestone("sshd is running")
      else
        @sshd_is_running = false
        Builtins.y2milestone("sshd is not running")
      end

      ports = SuSEFirewallServices.GetNeededTCPPorts(
        "libvirtd-relocation-server"
      )
      @libvirtd_ports = Builtins.filter(ports) do |s|
        s != @libvirtd_default_ports
      end

      true
    end

    def WriteLibvirtServices
      all_ok = true

      if GetLibvirtdOption("tunneled_migration") ||
          GetLibvirtdOption("plain_migration")
        all_ok = Service.Start("libvirtd") && all_ok if !@libvirtd_is_running
        all_ok = Service.Enable("libvirtd") && all_ok if !@libvirtd_enabled
      end
      if GetLibvirtdOption("tunneled_migration")
        all_ok = Service.Start("sshd") && all_ok if !@sshd_is_running
        all_ok = Service.Enable("sshd") && all_ok if !@sshd_enabled
      end
      if GetLibvirtdOption("plain_migration")
        if GetLibvirtdOption("default_port_range")
          if !Builtins.contains(@libvirtd_ports, @libvirtd_default_ports)
            @libvirtd_ports = Builtins.add(
              @libvirtd_ports,
              @libvirtd_default_ports
            )
          end
        end
        SuSEFirewallServices.SetNeededPortsAndProtocols(
          "libvirtd-relocation-server",
          { "tcp_ports" => @libvirtd_ports }
        )
      end

      all_ok
    end

    # Read all relocation-server settings
    # @return true on success
    def Read
      # RelocationServer read dialog caption
      caption = _("Initializing relocation-server Configuration")

      libvirt_steps = 2

      sl = 500
      Builtins.sleep(sl)

      libvirt_stg = [
        # Progress stage 1/2
        _("Read firewall settings"),
        # Progress stage 2/2
        _("Read the current libvirtd/sshd state")
      ]

      libvirt_tits = [
        # Progress step 1/2
        _("Reading firewall settings..."),
        # Progress stage 2/2
        _("Reading the current libvirtd/sshd state..."),
        # Progress finished
        Message.Finished
      ]

      Progress.New(caption, " ", libvirt_steps, libvirt_stg, libvirt_tits, "")

      return false if PollAbort()
      Progress.NextStage
      progress_state = Progress.set(false)
      # Error message
      Report.Warning(_("Cannot read firewall settings.")) if !SuSEFirewall.Read
      Progress.set(progress_state)
      Builtins.sleep(sl)

      return false if PollAbort()
      Progress.NextStage
      # Error message
      if !ReadLibvirtServices()
        Report.Error(_("Cannot read the current libvirtd/sshd state."))
        Report.Error(Message.CannotContinueWithoutPackagesInstalled)
        return false
      end
      Builtins.sleep(sl)

      return false if PollAbort()
      # Progress finished
      Progress.NextStage
      Builtins.sleep(sl)

      return false if PollAbort()
      @modified = false
      true
    end

    # Write all relocation-server settings
    # @return true on success
    def Write
      # RelocationServer read dialog caption
      caption = _("Saving relocation-server Configuration")

      libvirt_steps = 2

      sl = 500
      Builtins.sleep(sl)

      libvirt_stg = [
        # Progress stage 1
        _("Adjust the libvirtd/sshd service"),
        # Progress stage 2
        _("Write firewall settings")
      ]

      libvirt_tits = [
        # Progress step 1
        _("Adjusting the libvirtd/sshd service"),
        # Progress stage 2
        _("Writing firewall settings..."),
        Message.Finished
      ]

      Progress.New(caption, " ", libvirt_steps, libvirt_stg, libvirt_tits, "")

      return false if PollAbort()
      Progress.NextStage
      # Error message
      Report.Error(Message.CannotAdjustService("libvirt")) if !WriteLibvirtServices()
      Builtins.sleep(sl)

      return false if PollAbort()
      Progress.NextStage
      progress_state = Progress.set(false)
      # Error message
      Report.Error(_("Cannot write firewall settings.")) if !SuSEFirewall.Write
      Progress.set(progress_state)
      Builtins.sleep(sl)

      return false if PollAbort()
      # Progress finished
      Progress.NextStage
      Builtins.sleep(sl)

      return false if PollAbort()
      true
    end

    publish :function => :GetModified, :type => "boolean ()"
    publish :function => :SetModified, :type => "void ()"
    publish :function => :Abort, :type => "boolean ()"
    publish :function => :PollAbort, :type => "boolean ()"
    publish :function => :GetLibVirtdPorts, :type => "list <string> ()"
    publish :function => :SetLibvirtdPorts, :type => "void (list <string>)"
    publish :function => :GetLibvirtdOption, :type => "boolean (string)"
    publish :function => :SetLibvirtdOption, :type => "void (string, boolean)"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
  end

  RelocationServer = RelocationServerClass.new
  RelocationServer.main
end
