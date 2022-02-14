from qgis.PyQt.QtWidgets import QProgressBar,QMessageBox,QLabel
from qgis.PyQt.QtCore import Qt,QRect
from qgis.PyQt.QtGui import QMovie

from qgis.core import Qgis, QgsMessageLog
import os
import subprocess
from .constants import get_postgres_array
from .threads import install_pkg_thread

def has_qgis_pkg(dbLoader):
    """
    Check if current database has all the necessary view installed.
    This function helps to avoid new installation on top of existing ones (case when the plugin runs from start)
    """
    if 'qgis_pkg' in dbLoader.schemas:
        return True
    return False


def has_schema_views(dbLoader,schema): #TODO: TRY except, or plpgsql it in package
    cur = dbLoader.conn.cursor()
    cur.execute(""" SELECT table_name,'' FROM information_schema.tables 
	                WHERE table_schema = 'qgis_pkg' AND table_type = 'VIEW'""")
    views= cur.fetchall()
    views,empty = zip(*views)
    dbLoader.cur_schema_views=views     
    if any(schema in view for view in views):
        return True
    return False

        

def upd_conn_file(dbLoader):

    #Get selected connection details 
    database = dbLoader.dlg.cbxExistingConnection.currentData() 
    
    #Get plugin directory (parent dir of 'main')
    cur_dir = os.path.dirname(os.path.realpath(__file__))
    par_dir = os.path.join(cur_dir,os.pardir)

    if os.name == 'posix': #Linux or MAC

        #Create path to the 'connections' file
        path_connection_params = os.path.join(par_dir,dbLoader.plugin_package, 'CONNECTION_params.sh')

        #Get psql executable path
        cmd = ['which', 'psql']
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        o, e = proc.communicate()
        psql_path = o.decode('ascii') 
        

        #Rewrite the 'connections' file with current database parameters.
        with open (path_connection_params, 'w') as f:
            f.write(f"""\
#!/bin/bash

export PGHOST={database.host}
export PGPORT={database.port}
export CITYDB={database.database_name}
export PGUSER={database.username}
export PGBIN={psql_path}
""")    
        #Give executable rights    
        os.chmod(path_connection_params, 0o755)

    else: #Windows TODO: Find how to translate the above into windows batch
        pass
    return 0

def installation_query(dbLoader,message):
    selected_db=dbLoader.dlg.cbxExistingConnection.currentData()

    res= QMessageBox.question(dbLoader.dlg,"Installation", message)
    if res == 16384: #YES                
        upd_conn_file(dbLoader) #Prepares installation scripts with the connection parameters 
        success = install(dbLoader,dbLoader.dlg.lblInstallLoadingCon)
        if success: 
            selected_db.has_installation = True
            dbLoader.connection_status['Install']=True
            dbLoader.schemas.append(dbLoader.plugin_package)
            return True
        else:    
            dbLoader.connection_status['Install']=False
            dbLoader.dlg.btnClearDB.setDisabled(False)
            dbLoader.dlg.btnClearDB.setDefault(True)
            dbLoader.dlg.btnClearDB.setText(f'Clear corrupted installation!')  
            dbLoader.dlg.wdgMain.setCurrentIndex(2)                      
    else: 
        dbLoader.connection_status['Install']=False
    return False

def install(dbLoader,origin):
    """Origin relates to the mode of installation automatically/manually.
       But in practice it is the label object on which the loading anumation is going to play """
    #Get plugin directory
    selected_db=dbLoader.dlg.cbxExistingConnection.currentData()

    cur_dir = os.path.dirname(os.path.realpath(__file__))
    par_dir = os.path.join(cur_dir,os.pardir)
    os.chdir(par_dir)

    if os.name == 'posix': #Linux or MAC
        path_installation_sh = os.path.join(par_dir,dbLoader.plugin_package, 'CREATE_DB_qgis_pkg.sh')
        path_installation_sql = os.path.join(cur_dir,dbLoader.plugin_package, 'INSTALL_qgis_pkg.sql')
        
        #Give executable rights
        os.chmod(path_installation_sh, 0o755)

        #Run installation script

        install_pkg_thread(dbLoader,path_installation_sh,origin) #TODO: Need to catch error in the worker thread for logging and user msgs


        # p = subprocess.Popen(path_installation_sh,  stdin = subprocess.PIPE,
        #                                             stdout=subprocess.PIPE ,
        #                                             stderr=subprocess.PIPE ,
        #                                             universal_newlines=True)

        # output,e = p.communicate(f'{selected_db.password}\n')
        # if 'ERROR' in e:
        #     QgsMessageLog.logMessage('Installation failed!',level= Qgis.Critical,notifyUser=True)
        #     QgsMessageLog.logMessage(e[29:],level= Qgis.Info,notifyUser=True) #e[29:] skips manually 'Password for user postgres:', the stdin of the subprocess
        #     return 0
        # else: QgsMessageLog.logMessage(output,level= Qgis.Success,notifyUser=True)


    else: #Windows TODO: Find how to translate the above into windows batch
        pass
    return 1

def uninstall_pkg(dbLoader):
    progress = QProgressBar(dbLoader.dlg.gbxInstall.bar)
    progress.setMaximum(len(dbLoader.schemas))
    progress.setAlignment(Qt.AlignLeft|Qt.AlignVCenter)
    dbLoader.dlg.gbxInstall.bar.pushWidget(progress, Qgis.Info)

    if 'qgis_pkg' in dbLoader.schemas:
        cur = dbLoader.conn.cursor()
        cur.execute(f"""DROP SCHEMA qgis_pkg CASCADE""")

        dbLoader.conn.commit()

        msg = dbLoader.dlg.gbxInstall.bar.createMessage( u'Database has been cleared' )
        dbLoader.dlg.gbxInstall.bar.clearWidgets()
        dbLoader.dlg.gbxInstall.bar.pushWidget(msg, Qgis.Success, duration=4)
        
        dbLoader.dlg.cbxExistingConnection.currentData().has_installation = False
                     
    else:
        QgsMessageLog.logMessage('This message should never be able to be printed. Check installation.py ',level= Qgis.Critical,notifyUser=True)

def uninstall_views(dbLoader,schema):
    progress = QProgressBar(dbLoader.dlg.gbxInstall.bar)
    progress.setMaximum(len(dbLoader.schemas))
    progress.setAlignment(Qt.AlignLeft|Qt.AlignVCenter)
    dbLoader.dlg.gbxInstall.bar.pushWidget(progress, Qgis.Info)

    view_array=get_postgres_array(dbLoader.cur_schema_views)

    if 'qgis_pkg' in dbLoader.schemas:
        cur = dbLoader.conn.cursor()
        cur.execute(f"""    SELECT '-- DROP VIEW ' || table_name || ' CASCADE;' 
                            FROM information_schema.tables 
                            WHERE table_name SIMILAR TO '%{schema}%' and table_schema='qgis_pkg';""")

        dbLoader.conn.commit()

        msg = dbLoader.dlg.gbxInstall.bar.createMessage( u'Database has been cleared' )
        dbLoader.dlg.gbxInstall.bar.clearWidgets()
        dbLoader.dlg.gbxInstall.bar.pushWidget(msg, Qgis.Success, duration=4)
        
        dbLoader.dlg.cbxExistingConnection.currentData().has_installation = False
                     
    else:
        QgsMessageLog.logMessage('This message should never be able to be printed. Check installation.py ',level= Qgis.Critical,notifyUser=True)


# def refresh_schema_views(dbLoader):
#     import time

#     if 'qgis_pkg' in dbLoader.schemas:        
#         cur = dbLoader.conn.cursor()
        
#         cur.callproc("qgis_pkg.refresh_materialized_view")
        
#         for notice in dbLoader.conn.notices: #NOTE: It may take notices from other procs
#              QgsMessageLog.logMessage(notice,tag="3DCityDB-Loader",level= Qgis.Info)

#         #dbLoader.conn.commit()

#         msg = dbLoader.dlg.gbxInstall.bar.createMessage( u'Views have been succesfully updated' )
#         dbLoader.dlg.gbxInstall.bar.clearWidgets()
#         dbLoader.dlg.gbxInstall.bar.pushWidget(msg, Qgis.Success, duration=4)
        
                     
#     else:
#         QgsMessageLog.logMessage('This message should never be able to be printed. Check installation.py ',level= Qgis.Critical,notifyUser=True)
