import sys
import os
import subprocess

def debug():
    print("=== PYTHON DEBUG INFO ===")
    print(f"Python Version: {sys.version}")
    print(f"Python Executable: {sys.executable}")
    print(f"Current User ID: {os.getuid()}")
    print(f"Current Working Directory: {os.getcwd()}")
    
    print("\n=== SYS PATH (Where Python looks for libs) ===")
    for path in sys.path:
        print(f" - {path}")

    print("\n=== PIP LIST (What is actually installed) ===")
    try:
        pip_list = subprocess.check_output([sys.executable, "-m", "pip", "list"]).decode()
        print(pip_list)
    except Exception as e:
        print(f"Could not run pip list: {e}")

    print("\n=== SEARCHING FOR NUMPY ===")
    try:
        import numpy
        print(f"Numpy found at: {numpy.__file__}")
        print(f"Numpy version: {numpy.__version__}")
    except ImportError:
        print("Numpy NOT FOUND in import")

    print("\n=== DIRECTORY CHECK ===")
    check_paths = [
        "/usr/local/lib/python3.11/dist-packages",
        "/usr/local/lib/python3.10/dist-packages",
        "/usr/lib/python3/dist-packages",
        "/opt/python_libs"
    ]
    for p in check_paths:
        exists = os.path.exists(p)
        print(f"Path {p} exists: {exists}")
        if exists:
            try:
                content = os.listdir(p)
                print(f"  First 5 items: {content[:5]}")
            except Exception as e:
                print(f"  Could not list: {e}")

if __name__ == "__main__":
    debug()