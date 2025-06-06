#!/usr/bin/env python3
"""
Test script for the Smart Bidirectional File Sync utility.

This script creates two temporary directories, adds some files to them,
and then runs the smart_sync.py script to demonstrate bidirectional synchronization
with the "most recent version wins" strategy.

Usage:
    python test_smart_sync.py
"""

import os
import shutil
import subprocess
import tempfile
import time
import sys


def create_test_file(directory, filename, content):
    """Create a test file with the given content."""
    file_path = os.path.join(directory, filename)
    with open(file_path, "w") as f:
        f.write(content)
    print(f"Created: {file_path}")
    # Ensure the file has a unique modification time
    time.sleep(0.1)
    return file_path


def main():
    """Run a demonstration of the smart file sync utility."""
    # Create two temporary directories
    dir1 = tempfile.mkdtemp(prefix="smart_sync_test_dir1_")
    dir2 = tempfile.mkdtemp(prefix="smart_sync_test_dir2_")

    print(f"\nCreated test directories:")
    print(f"Directory 1: {dir1}")
    print(f"Directory 2: {dir2}")

    try:
        # Create some initial files in dir1
        print("\nCreating initial files in Directory 1...")
        create_test_file(dir1, "file1.txt", "This is file 1 content")
        create_test_file(dir1, "file2.txt", "This is file 2 content")

        # Create a subdirectory with a file in dir1
        subdir1 = os.path.join(dir1, "subdir")
        os.makedirs(subdir1)
        create_test_file(subdir1, "subfile1.txt", "This is a file in a subdirectory")

        # Create a different file in dir2
        print("\nCreating initial files in Directory 2...")
        create_test_file(dir2, "file3.txt", "This is file 3 content")

        # Create a file with the same name in both directories but different content
        # The one in dir2 will be newer (created later)
        print("\nCreating a file with the same name in both directories...")
        create_test_file(dir1, "common.txt", "This is the common file in dir1")
        time.sleep(1)  # Ensure dir2 version has a newer timestamp
        create_test_file(
            dir2, "common.txt", "This is the common file in dir2 (NEWER VERSION)"
        )

        # Start the file sync in a subprocess
        print("\nStarting file sync (will run for 30 seconds)...")

        # Construct the command to run smart_sync.py
        script_dir = os.path.dirname(os.path.abspath(__file__))
        sync_script = os.path.join(script_dir, "smart_sync.py")

        # Start the sync process
        sync_process = subprocess.Popen(
            [sys.executable, sync_script, dir1, dir2, "--ignore", "*.tmp", "*.log"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True,
        )

        # Give the sync process time to perform initial sync
        time.sleep(5)

        # Check which version of common.txt was kept (should be the newer one from dir2)
        print("\nChecking which version of common.txt was kept...")
        with open(os.path.join(dir1, "common.txt"), "r") as f:
            content = f.read()
        print(f"Content of common.txt in dir1: {content}")

        # Demonstrate file creation in dir1
        print("\nCreating a new file in Directory 1...")
        create_test_file(
            dir1, "new_file_in_dir1.txt", "This file was created after sync started"
        )
        time.sleep(2)

        # Demonstrate file creation in dir2
        print("\nCreating a new file in Directory 2...")
        create_test_file(
            dir2,
            "new_file_in_dir2.txt",
            "This file was created in dir2 after sync started",
        )
        time.sleep(2)

        # Demonstrate file modification - update a file in dir1 that exists in both
        print("\nModifying a file in Directory 1...")
        create_test_file(
            dir1, "file3.txt", "This is file 3 with MODIFIED content from dir1"
        )
        time.sleep(2)

        # Demonstrate file modification - update the same file in dir2 but with a newer timestamp
        print("\nModifying the same file in Directory 2 (this should win)...")
        time.sleep(1)  # Ensure dir2 version has a newer timestamp
        create_test_file(
            dir2, "file3.txt", "This is file 3 with NEWER MODIFIED content from dir2"
        )
        time.sleep(2)

        # Check which version was kept (should be the newer one from dir2)
        print("\nChecking which version of file3.txt was kept...")
        with open(os.path.join(dir1, "file3.txt"), "r") as f:
            content = f.read()
        print(f"Content of file3.txt in dir1: {content}")

        # Demonstrate file deletion
        print("\nDeleting a file in Directory 2...")
        os.remove(os.path.join(dir2, "file1.txt"))
        time.sleep(2)

        # Check if the file was also deleted from dir1
        deleted_in_dir1 = not os.path.exists(os.path.join(dir1, "file1.txt"))
        print(
            f"File1.txt was {'deleted from dir1 (CORRECT)' if deleted_in_dir1 else 'not deleted from dir1 (ERROR)'}"
        )

        # Demonstrate ignored files
        print("\nCreating an ignored file in Directory 1...")
        create_test_file(dir1, "ignored.tmp", "This file should be ignored")
        time.sleep(2)

        # Check if the ignored file was synced
        ignored_in_dir2 = os.path.exists(os.path.join(dir2, "ignored.tmp"))
        print(
            f"Ignored file was {'synced (ERROR)' if ignored_in_dir2 else 'not synced (CORRECT)'}"
        )

        # Let the sync process run for a bit longer
        print("\nWaiting for sync to complete...")
        time.sleep(5)

        # List the contents of both directories
        print("\nFinal contents of Directory 1:")
        for root, dirs, files in os.walk(dir1):
            for file in files:
                print(f"  {os.path.relpath(os.path.join(root, file), dir1)}")

        print("\nFinal contents of Directory 2:")
        for root, dirs, files in os.walk(dir2):
            for file in files:
                print(f"  {os.path.relpath(os.path.join(root, file), dir2)}")

        # Terminate the sync process
        print("\nStopping file sync...")
        sync_process.terminate()
        sync_process.wait()

        # Print the output from the sync process
        print("\nOutput from file sync process:")
        output, _ = sync_process.communicate()
        print(output)

    finally:
        # Clean up the temporary directories
        print("\nCleaning up test directories...")
        shutil.rmtree(dir1, ignore_errors=True)
        shutil.rmtree(dir2, ignore_errors=True)
        print("Test completed.")


if __name__ == "__main__":
    main()
