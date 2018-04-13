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

# File:	include/relocation-server/helps.ycp
# Package:	Configuration of relocation-server
# Summary:	Help texts of all the dialogs
# Authors:	Li Dongyang <lidongyang@novell.com>
#
# $Id: helps.ycp 27914 2006-02-13 14:32:08Z locilka $
module Yast
  module RelocationServerHelpsInclude
    def initialize_relocation_server_helps(include_target)
      textdomain "relocation-server"

      # All helps are here
      @HELPS = {
        # Read dialog help 1/2
        "read"               => _(
          "<p><b><big>Initializing relocation-server Configuration</big></b><br>\nPlease wait...<br></p>\n"
        ) +
          # Read dialog help 2/2
          _(
            "<p><b><big>Aborting Initialization:</big></b><br>\nSafely abort the configuration utility by pressing <b>Abort</b> now.</p>\n"
          ),
        # Write dialog help 1/2
        "write"              => _(
          "<p><b><big>Saving relocation-server Configuration</big></b><br>\nPlease wait...<br></p>\n"
        ) +
          # Write dialog help 2/2
          _(
            "<p><b><big>Aborting Saving:</big></b><br>\n" +
              "Abort the save procedure by pressing <b>Abort</b>.\n" +
              "An additional dialog informs whether it is safe to do so.\n" +
              "</p>\n"
          ),
        "libvirt_configuration"  => _(
          "<p><b><big>Tunneled migration</big></b><br>\n" +
            "The source host libvirtd opens a direct connection to the destination host libvirtd for sending migration data. This allows the option of encrypting the data stream.</p>\n" +
            "<p><b><big>Plain migration</big></b><br>\n" +
            "The source host VM opens a direct unencrypted TCP connection to the destination host for sending the migration data. Unless a port is manually specified, libvirt will choose a migration port in the default range.</p>"
        )
      } 

      # EOF
    end
  end
end
