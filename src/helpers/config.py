import configparser

class udroidConfig:
    CONFIG_FILE_PATH = None
    
    def __init__(self, config_path: str):
        self.CONFIG_FILE_PATH = config_path
        