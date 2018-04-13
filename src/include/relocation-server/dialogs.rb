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

# File:	include/relocation-server/dialogs.ycp
# Package:	Configuration of relocation-server
# Summary:	Dialogs definitions
# Authors:	Li Dongyang <lidongyang@novell.com>
#
# $Id: dialogs.ycp 27914 2006-02-13 14:32:08Z locilka $
module Yast
  module RelocationServerDialogsInclude
    def initialize_relocation_server_dialogs(include_target)
      textdomain "relocation-server"

      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "RelocationServer"

      Yast.include include_target, "relocation-server/helps.rb"
    end

    def LibvirtConfigurationDialogContent
      VBox(
        Frame(
          _("Tunneled migration"),
          VBox(
            Left(
              CheckBox(
                Id("tunneled_migration"),
                Opt(:notify),
                _("Make sure tunneled migration works")
              )
            )
          )
        ),
        Frame(
          _("Plain migration"),
          VBox(
            Left(
              CheckBox(
                Id("plain_migration"),
                Opt(:notify),
                _("Make sure plain migration works")
              )
            ),
            VSpacing(),
            Left(Label(_("TCP Ports"))),
            Left(
              MinSize(
                40,
                5,
                # A table header
                Table(Id("Port"), Header(_("Port")), [])
              )
            ),
            Left(
              HBox(
                # a push button
                PushButton(Id("add_port"), _("&Add...")),
                # a push button
                PushButton(Id("edit_port"), _("&Edit...")),
                # a push button
                PushButton(Id("delete_port"), _("&Delete"))
              )
            ),
            Left(
              CheckBox(
                Id("default_port_range"),
                Opt(:notify),
                _("Include default port range")
              )
            )
          )
        ),
        Frame(_("Firewall"), VBox("fw-libvirt"))
      )
    end
  end
end
