# -*- coding: utf-8 -*-
"""
/***************************************************************************
 DBLoaderDialog
                                 A QGIS plugin
                    This is an experimental plugin for 3DCityDB.
 Generated by Plugin Builder: http://g-sherman.github.io/Qgis-Plugin-Builder/
                             -------------------
        begin                : 2021-09-30
        git sha              : $Format:%H$
        copyright            : (C) 2021 by Konstantinos Pantelios
        email                : konstantinospantelios@yahoo.com
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
"""


import os

from qgis.PyQt import uic
from qgis.PyQt import QtWidgets
from qgis.PyQt.QtGui import QMovie


# This loads the .ui file so that PyQt can populate the plugin
# with the elements from Qt Designer
FORM_CLASS, _ = uic.loadUiType(os.path.join(
    os.path.dirname(__file__), "ui","citydb_loader_dialog_base.ui"))

class DBLoaderDialog(QtWidgets.QDialog, FORM_CLASS):
    """Main Dialog of the plugin.
    The gui is imported from an external .ui xml
    """

    def __init__(self, parent=None):
        """Constructor."""
        super(DBLoaderDialog, self).__init__(parent)
        # Set up the user interface from Designer through FORM_CLASS.
        # After self.setupUi() you can access any designer object by doing
        # self.<objectname>, and you can use autoconnect slots - see
        # http://qt-project.org/doc/qt-4.8/designer-using-a-ui-file.html
        # #widgets-and-dialogs-with-auto-connect
        self.setupUi(self)

        # Hide label reserved for the loading animation.
        self.lblInstallLoadingCon.setHidden(True)
        self.lblLoadingClear.setHidden(True)
        self.lblLoadingInstall.setHidden(True)
        self.lblLoadingUninstall.setHidden(True)
        self.lblLoadingRefresh.setHidden(True)

        self.movie = QMovie(':/plugins/citydb_loader/icons/loading.gif')
