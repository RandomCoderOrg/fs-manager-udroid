import subprocess
import os
from typing import Iterable

def exec(cmd, log_file: None | str = None):
    try:
        # Execute and create a subprocess
        # cmd: str = shlex.split(cmd)
        
        handler = miniFileHandler(log_file)
        
        process = subprocess.Popen(
            args=cmd, shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True
        )
        
        # Get the PID of the subprocess ( just for debugging )
        pid = process.pid
        print(f'Process {cmd} {pid} started')
        

        # Read and capture the output of the subprocess
        print("reached Iter")
        while True:
            stdout = process.stdout.readline()
            if stdout == '' and process.poll() is not None:
                handler.close()
                break
            if stdout:
                handler.writelines(stdout)

        return process.wait()
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: ", e)

def debug(msg):
    if os.environ.get('DEBUG'):
        print(msg)

class miniFileHandler:
    file_path=""
    file_path_io = None
    
    def __init__(self, file_path: str | None):
        self.file_path = file_path
        if file_path is not None:
            self.file_path_io = open(file_path, '+w')
    
    def close(self):
        if self.file_path_io is not None:
            self.file_path_io.close()
    
    def file(self):
        if self.file_path_io is not None:
            return self.file_path_io
    
    def writelines(self, line: Iterable[str]):
        if self.file_path_io is not None:
            self.file_path_io.writelines(line)
        else:
            print(line)
