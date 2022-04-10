def lwarn(msg):
    print("[W] " + msg)

def nmsg(msg):
    print("* " + msg)

def die(msg):
    print("[E] " + msg)
    exit(1)

## COLORS
def red(msg):
    return "\033[1;31m" + msg + "\033[0m"

def blue(msg):
    return "\033[1;34m" + msg + "\033[0m"

def green(msg):
    return "\033[1;32m" + msg + "\033[0m"

def magneta(msg):
    return "\033[1;35m" + msg + "\033[0m"
