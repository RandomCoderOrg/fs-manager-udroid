import unittest, os, tempfile
import src.helpers.cmd as cmd

os.environ['DEBUG'] = 'set'

class TestExec(unittest.TestCase):
    
    def teste_exec_echo(self):
        self.assertEquals(cmd.exec('echo hello'), 0, 'test command exec')
    
    def test_exec_log_file_generation(self):
        tmp_file = tempfile.mktemp("test-XXXXXXXX")
        print(tmp_file)
        exec = cmd.exec("echo hello", tmp_file)
        self.assertTrue(os.path.exists(tmp_file))
        self.assertEqual(exec, 0)
        
        with open(tmp_file, 'r') as f:
            content = f.readlines()
            print("=>", content)
            self.assertListEqual(content, ['hello\n'])

        

if __name__ == '__main__':
    unittest.main()
