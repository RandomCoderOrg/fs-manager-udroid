import os
import sys
import optparse
from utils.info import *
from utils.funs import *

def vnc_mode(port=1,mode="start",xstartup=os.getenv('HOME')+"/.vnc/xstartup"):
    import utils.vnc as vnc
    
    if os.path.exists(xstartup):
        if mode == "start":
            if vnc.startvnc(port):
                print(vncokdialog(port))
            else:
                print(vncrunningdialog(port))
        elif mode == "stop":
            if vnc.stopvnc(port):
                print(vnckilldialog(port))
            else:
                print("No VNC server running at "+str(port))
    else:
        print("xstartup file not found")

if __name__ == '__main__':
    parser =  optparse.OptionParser()
    parser.add_option("--startvnc",action='store_true', default=True, help="Start VNC on port")
    parser.add_option("--stopvnc" ,action='store_true', default=True, help="Stop VNC on port")
    parser.add_option("-p", "--port", help="VNC port", default=1)

    (options, args) = parser.parse_args()

    if options.startvnc:
        vnc_mode(port=options.port,mode="start")
        sys.exit(0)
    elif options.stopvnc:
        vnc_mode(port=options.port,mode="stop")
        sys.exit(0)
    
