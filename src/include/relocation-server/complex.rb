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
  module RelocationServerComplexInclude
    def initialize_relocation_server_complex(include_target)
      textdomain "relocation-server"

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Confirm"
      Yast.import "CWMFirewallInterfaces"
      Yast.import "RelocationServer"


      Yast.include include_target, "relocation-server/helps.rb"
    end

    def ReallyExit
      # yes-no popup
      Popup.YesNo(_("Really exit?\nAll changes will be lost."))
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      Wizard.RestoreHelp(Ops.get_string(@HELPS, "read", ""))
      Wizard.SetDesktopIcon("org.opensuse.yast.RelocationServer")
      # RelocationServer::SetAbortFunction(PollAbort);
      return :abort if !Confirm.MustBeRoot
      ret = RelocationServer.Read
      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      Wizard.RestoreHelp(Ops.get_string(@HELPS, "write", ""))
      Wizard.SetDesktopIcon("org.opensuse.yast.RelocationServer")
      # RelocationServer::SetAbortFunction(PollAbort);
      ret = RelocationServer.Write
      ret ? :next : :abort
    end

    def InitLibvirtFireWall
      tunneled_migration = Convert.to_boolean(
        UI.QueryWidget(Id("tunneled_migration"), :Value)
      )
      plain_migration = Convert.to_boolean(
        UI.QueryWidget(Id("plain_migration"), :Value)
      )
      if tunneled_migration || plain_migration
        CWMFirewallInterfaces.EnableOpenFirewallWidget
      else
        CWMFirewallInterfaces.DisableOpenFirewallWidget
      end

      nil
    end

    def InitLibvirtdPortsTable
      ports = RelocationServer.GetLibVirtdPorts
      stat = Convert.to_boolean(UI.QueryWidget(Id("plain_migration"), :Value))

      if ports != nil && ports != []
        items = []
        Builtins.foreach(ports) do |port|
          items = Builtins.add(items, Item(Id(port), port))
        end

        # Redraw table of ports and enable modification buttons
        UI.ChangeWidget(Id("Port"), :Items, items)
        UI.ChangeWidget(Id("edit_port"), :Enabled, true && stat)
        UI.ChangeWidget(Id("delete_port"), :Enabled, true && stat)
      else
        # Redraw table of ports and disable modification buttons
        UI.ChangeWidget(Id("Port"), :Items, [])
        UI.ChangeWidget(Id("edit_port"), :Enabled, false)
        UI.ChangeWidget(Id("delete_port"), :Enabled, false)
      end

      UI.ChangeWidget(Id("Port"), :Enabled, stat)
      UI.ChangeWidget(Id("add_port"), :Enabled, stat)
      UI.ChangeWidget(Id("default_port_range"), :Enabled, stat)

      nil
    end

    def InitLibvirtConfigurationDialog(id)
      UI.ChangeWidget(Id("tunneled_migration"), :Value, false)
      UI.ChangeWidget(Id("plain_migration"), :Value, false)
      UI.ChangeWidget(Id("default_port_range"), :Value, true)
      InitLibvirtdPortsTable()
      InitLibvirtFireWall()

      nil
    end

    def DeletePort(port)
      ports = RelocationServer.GetLibVirtdPorts
      ports = Builtins.filter(ports) { |s| s != port }
      RelocationServer.SetLibvirtdPorts(ports)

      nil
    end

    def AddEditPortDialog(current_port)
      UI.OpenDialog(
        Opt(:decorated),
        VBox(
          MinWidth(
            30,
            HBox(
              HSpacing(1),
              Frame(
                current_port == nil ?
                  # A popup dialog caption
                  _("Add New Port") :
                  # A popup dialog caption
                  _("Edit Current Port"),
                # A text entry
                TextEntry(
                  Id("port_number"),
                  _("&Port"),
                  current_port == nil ? "" : current_port
                )
              ),
              HSpacing(1)
            )
          ),
          VSpacing(1),
          ButtonBox(
            PushButton(Id(:ok), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      UI.ChangeWidget(Id("port_number"), :ValidChars, "0123456789")

      ret = nil
      while true
        ret = UI.UserInput
        if ret == :ok
          new_port = Convert.to_string(
            UI.QueryWidget(Id("port_number"), :Value)
          )

          if new_port == ""
            UI.SetFocus(Id("port_number"))
            Report.Error(_("Port number must not be empty."))
            next
          end

          if Ops.greater_than(Builtins.tointeger(new_port), 65535) ||
              Ops.less_than(Builtins.tointeger(new_port), 1)
            UI.SetFocus(Id("port_number"))
            Report.Error(_("Port number out of range."))
            next
          end

          ports = RelocationServer.GetLibVirtdPorts
          if Builtins.contains(ports, new_port)
            UI.SetFocus(Id("port_number"))
            Report.Error(_("Port number already exists."))
            next
          end
          ports = Builtins.add(ports, new_port)
          RelocationServer.SetLibvirtdPorts(ports)

          DeletePort(current_port) if current_port != nil
        end

        break
      end

      UI.CloseDialog

      nil
    end

    def HandleLibvirtConfigurationDialog(id, event)
      event = deep_copy(event)
      action = Ops.get(event, "ID")
      selected_port = Convert.to_string(
        UI.QueryWidget(Id("Port"), :CurrentItem)
      )

      # Adding a new port
      if action == "add_port"
        AddEditPortDialog(nil) 
        # Editing current port
      elsif action == "edit_port"
        AddEditPortDialog(selected_port) 
        # Deleting current port
      elsif action == "delete_port"
        DeletePort(selected_port) if Confirm.DeleteSelected
      elsif action == "tunneled_migration" || action == "plain_migration"
        InitLibvirtFireWall()
      end


      InitLibvirtdPortsTable()
      nil
    end

    def StoreLibvirtConfigurationDialog(id, event)
      event = deep_copy(event)
      RelocationServer.SetModified

      Builtins.foreach(
        ["tunneled_migration", "plain_migration", "default_port_range"]
      ) do |key|
        value = Convert.to_boolean(UI.QueryWidget(Id(key), :Value))
        RelocationServer.SetLibvirtdOption(key, value)
      end

      nil
    end
  end
end
