"""This module contains functions that relate to the package Installation
operations.

These functions are usually called from widget_setup functions
relating to child widgets of the 'Settings Tab' or 'Connection Tab'
as from either of these tabs installation,uninstallation processes
can commence.

..(04-03-22) The functions where reduced by a LOT, so this whole
.. file seems a bit redundant. Think of how to consume it.
"""

from qgis.PyQt.QtWidgets import QMessageBox

from . import constants as c
from .proc_functions import sql
from .proc_functions import pf_dbadmin_tab as dba_tab
from .proc_functions import threads as th

def installation_query(dbLoader, message: str, inst_type: str) -> None:
    """Function that prompts the user to install
    the plugin packages in the database.

    *   :param message: Text to show the user.

        :param message: str

    *   :param inst_type: Type of installation either 'main' or 'user'

        :param inst_type: str (main|user)
    """

    if inst_type == "main":
        #message = message.format(pkg=c.MAIN_PKG_NAME)
        res= QMessageBox.question(dbLoader.dlg_admin,"Installation", message)
        if res == 16384: #YES
            th.install_pkg_thread(dbLoader, path=c.MAIN_INST_PATH, pkg=c.MAIN_PKG_NAME)
            return True
        return False
    elif inst_type == "user":
        #message = message.format(usr=c.USER_PKG_NAME.format(user=dbLoader.DB.username))
        res= QMessageBox.question(dbLoader.dlg_admin,"Installation", message)
        if res == 16384: #YES
            sql.exec_create_qgis_usr_schema(dbLoader)
            dbLoader.dlg_admin.btnUsrUninst.setDisabled(False)
            return True
        dbLoader.dlg_admin.btnUsrUninst.setDisabled(True)
        return False
    else:
        QMessageBox.critical(dbLoader.dlg_admin,"Installation", "Unrecognised inst type!")
        return False

def uninstallation_query(dbLoader, message: str, uninst_type: str) -> None:
    """Function that uninstalls the plugin package from the
    user's database.

    *   :param message: Text to show the user.

        :param message: str

    *   :param inst_type: Type of installation either 'main' or 'user'

        :param inst_type: str (main|user)

    """
    if uninst_type == "main":
        #message = message.format(pkg=c.MAIN_PKG_NAME)
        res= QMessageBox.question(dbLoader.dlg_admin,"Uninstallation", message)
        if res == 16384: #YES
            th.uninstall_pkg_thread(dbLoader)
            return True
        return False
    elif uninst_type == "user":
        #message = message.format(usr=c.USER_PKG_NAME.format(user=dbLoader.DB.username))
        res= QMessageBox.question(dbLoader.dlg_admin,"Uninstallation", message)
        if res == 16384: #YES
            # Run scripts
            th.drop_usr_sch_thread(dbLoader)
            return True
        return False
    else:
        QMessageBox.critical(dbLoader.dlg_admin,"Uninstallation", "Unrecognised uninst type!")
        return False