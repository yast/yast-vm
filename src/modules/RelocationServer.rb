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
require "y2firewall/firewalld"

module Yast
  class RelocationServerClass < Module
    include Yast::Logger
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

      # Data was modified?
      @modified = false

      # map of xend settings
      @SETTINGS = {}

      @DEFAULT_CONFIG = {
        "xend-relocation-server"               => "no",
        "xend-relocation-ssl-server"           => "no",
        "xend-relocation-port"                 => "8002",
        "xend-relocation-ssl-port"             => "8003",
        "xend-relocation-server-ssl-key-file"  => "xmlrpc.key",
        "xend-relocation-server-ssl-cert-file" => "xmlrpc.cert",
        "xend-relocation-ssl"                  => "no",
        "xend-relocation-address"              => "",
        "xend-relocation-hosts-allow"          => "^localhost$ ^localhost\\.localdomain$"
      }

      # Describes whether the daemon is running
      @xend_is_running = false

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

    # Convenience method for obtaining a firewalld singleton instance
    #
    # @return [Y2Firewall::Firewalld] singleton instance
    def firewalld
      Y2Firewall::Firewalld.instance
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

    # Determine if we are using the libxl toolstack
    def is_xend
      if !Arch.is_xen0 || !FileUtils.Exists("/etc/vm/xend-config.sxp") || !FileUtils.Exists("/usr/sbin/xend")
        return false
      end

      true
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

    # Returns the Xend Option as a list of strings.
    #
    # @param [String] option_key of the xend configuration
    # @return [String] with option_values
    def GetXendOption(option_key)
      Ops.get(@SETTINGS, option_key, Ops.get(@DEFAULT_CONFIG, option_key, ""))
    end

    # Returns default Xend Option as a list of strings.
    #
    # @param [String] option_key of the Xend configuration
    # @return [String] with option_values

    def GetDefaultXendOption(option_key)
      Ops.get(@DEFAULT_CONFIG, option_key, "")
    end

    # Sets values for an option.
    #
    # @param [String] option_key with the Xend configuration key
    # @param string option_values with the Xend configuration values
    def SetXendOption(option_key, option_vals)
      Ops.set(@SETTINGS, option_key, option_vals)

      nil
    end

    # Reads current xend configuration
    def ReadXendSettings
      Builtins.foreach(SCR.Dir(path(".etc.xen.xend-config"))) do |key|
        val = Convert.to_string(
          SCR.Read(Builtins.add(path(".etc.xen.xend-config"), key))
        )
        Ops.set(@SETTINGS, key, val) if val != nil
      end

      Builtins.y2milestone("Xend configuration has been read: %1", @SETTINGS)
      true
    end

    FWD_XEND_SERVICE = "xend-relocation-server".freeze
    FWD_LIBVIRTD_SERVICE = "libvirtd-relocation-server".freeze

    # Writes current xend configuration
    def WriteXendSettings
      Builtins.y2milestone("Writing Xend configuration: %1", @SETTINGS)

      Builtins.foreach(@SETTINGS) do |option_key, option_val|
        SCR.Write(
          Builtins.add(path(".etc.xen.xend-config"), option_key),
          option_val
        )
      end
      # This is very important
      # it flushes the cache, and stores the configuration on the disk
      SCR.Write(path(".etc.xen.xend-config"), nil)

      port = GetXendOption("xend-relocation-port")
      ssl_port = GetXendOption("xend-relocation-ssl-port")
      ports_list = [port, ssl_port]

      begin
        Y2Firewall::Firewalld::Service.modify_ports(name: FWD_XEND_SERVICE, tcp_ports: ports_list)
      rescue Y2Firewall::Firewalld::Service::NotFound
        y2error("Firewalld '#{FWD_XEND_SERVICE}' service is not available.")
      end

      true
    end

    # Reads current xend status
    def ReadXendService
      xend = "/usr/sbin/xend"
      retval = 1
      if FileUtils.Exists(xend)
        retval = Convert.to_integer(SCR.Execute(path(".target.bash_output"), Builtins.sformat("%1 status", xend)))
      end
      if retval == 0
        @xend_is_running = true
        Builtins.y2milestone("Xend is running")
      else
        @xend_is_running = false
        Builtins.y2milestone("Xend is not running")
      end

      true
    end

    # Restarts the xend when the daemon was running when starting the configuration
    def WriteXendService
      all_ok = true

      if @xend_is_running
        Builtins.y2milestone("Restarting xend daemon")
        all_ok = Service.Restart("xend")
      else
        Builtins.y2milestone("Xend is not running - leaving...")
      end

      all_ok
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

      begin
        fwd_libvirt = firewalld.find_service("libvirtd-relocation_service")
        ports = fwd_libvirt.tcp_ports
      rescue Y2Firewall::Firewalld::Service::NotFound
        ports = []
      end

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
        begin
          Y2Firewall::Firewalld::Service.modify_ports(name: FWD_LIBVIRTD_SERVICE, tcp_ports: @libvirtd_ports)
        rescue Y2Firewall::Firewalld::Service::NotFound
          y2error("Firewalld '#{FWD_LIBVIRTD_SERVICE}' service is not available.")
        end
      end

      all_ok
    end

    # Read all relocation-server settings
    # @return true on success
    def Read
      # RelocationServer read dialog caption
      caption = _("Initializing relocation-server Configuration")

      xen_steps = 3
      libvirt_steps = 2

      sl = 500
      Builtins.sleep(sl)

      xen_stg = [
        # Progress stage 1/3
        _("Read the current xend configuration"),
        # Progress stage 2/3
        _("Read the current xend state"),
        # Progress stage 3/3
        _("Read firewall settings")
      ]

      xen_tits = [
        # Progress step 1/3
        _("Reading the current xend configuration..."),
        # Progress step 2/3
        _("Reading the current xend state..."),
        # Progress step 3/3
        _("Reading firewall settings..."),
        # Progress finished
        Message.Finished
      ]

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

      if is_xend()
        Progress.New(caption, " ", xen_steps, xen_stg, xen_tits, "")
      else
        Progress.New(caption, " ", libvirt_steps, libvirt_stg, libvirt_tits, "")
      end

      if is_xend()
        return false if PollAbort()
        Progress.NextStage
        # Error message
        Report.Error(Message.CannotReadCurrentSettings) if !ReadXendSettings()
        Builtins.sleep(sl)

        return false if PollAbort()
        Progress.NextStage
        # Error message
        if !ReadXendService()
          Report.Error(_("Cannot read the current Xend state."))
        end
        Builtins.sleep(sl)
      end

      return false if PollAbort()
      Progress.NextStage
      progress_state = Progress.set(false)
      # Error message
      Report.Warning(_("Cannot read firewall settings.")) if !firewalld.read
      Progress.set(progress_state)
      Builtins.sleep(sl)

      if Arch.is_kvm || !is_xend()
        return false if PollAbort()
        Progress.NextStage
        # Error message
        if !ReadLibvirtServices()
          Report.Error(_("Cannot read the current libvirtd/sshd state."))
          Report.Error(Message.CannotContinueWithoutPackagesInstalled)
          return false
        end
        Builtins.sleep(sl)
      end

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

      xen_steps = 3
      libvirt_steps = 2

      sl = 500
      Builtins.sleep(sl)

      xen_stg = [
        # Progress stage 1
        _("Write the Xend settings"),
        # Progress stage 2
        _("Adjust the Xend service"),
        # Progress stage 3
        _("Write firewall settings")
      ]

      xen_tits = [
        # Progress step 1
        _("Writing the Xend settings..."),
        # Progress step 2
        _("Adjusting the Xend service..."),
        # Progress step 3
        _("Writing firewall settings..."),
        Message.Finished
      ]

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

      if is_xend()
        Progress.New(caption, " ", xen_steps, xen_stg, xen_tits, "")
      else
        Progress.New(caption, " ", libvirt_steps, libvirt_stg, libvirt_tits, "")
      end

      if is_xend()
        return false if PollAbort()
        Progress.NextStage
        # Error message
        if !WriteXendSettings()
          Report.Error(_("Cannot write the xend settings."))
        end
        Builtins.sleep(sl)

        return false if PollAbort()
        Progress.NextStage
        # Error message
        Report.Error(Message.CannotAdjustService("xend")) if !WriteXendService()
        Builtins.sleep(sl)
      else
        return false if PollAbort()
        Progress.NextStage
        # Error message
        Report.Error(Message.CannotAdjustService("xend")) if !WriteLibvirtServices()
        Builtins.sleep(sl)
      end

      return false if PollAbort()
      Progress.NextStage
      progress_state = Progress.set(false)
      # Error message
      Report.Error(_("Cannot write firewall settings.")) if !firewalld.write
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
    publish :function => :GetXendOption, :type => "string (string)"
    publish :function => :GetDefaultXendOption, :type => "string (string)"
    publish :function => :SetXendOption, :type => "void (string, string)"
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
