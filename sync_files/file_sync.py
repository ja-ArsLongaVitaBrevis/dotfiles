#!/usr/bin/env python3
"""
Bidirectional File Sync Script

This script monitors two directories and keeps them in sync by copying any
modified, new, or deleted files between them, preserving the directory structure.

Usage:
    python file_sync.py /path/to/dir1 /path/to/dir2 [--ignore pattern1 pattern2 ...]
"""

import argparse
import os
import shutil
import time
import fnmatch
import logging
from datetime import datetime, timedelta
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# Global dictionary to track recent events to prevent sync loops
recent_events = {}
# Time window to consider events as duplicates (in seconds)
EVENT_WINDOW = 2


class SyncHandler(FileSystemEventHandler):
    """
    Handler for file system events that syncs files bidirectionally.
    """

    def __init__(self, source_dir, target_dir, ignore_patterns=None):
        """
        Initialize the handler with source and target directories.

        Args:
            source_dir (str): Source directory path to monitor
            target_dir (str): Target directory path to sync with
            ignore_patterns (list): List of patterns to ignore
        """
        self.source_dir = os.path.abspath(source_dir)
        self.target_dir = os.path.abspath(target_dir)
        self.ignore_patterns = ignore_patterns or []
        logger.info(f"Monitoring {self.source_dir} for changes")
        logger.info(f"Syncing with {self.target_dir}")
        if self.ignore_patterns:
            logger.info(f"Ignoring patterns: {', '.join(self.ignore_patterns)}")

    def should_ignore(self, path):
        """
        Check if a path should be ignored based on ignore patterns.

        Args:
            path (str): Path to check

        Returns:
            bool: True if path should be ignored, False otherwise
        """
        rel_path = os.path.relpath(path, self.source_dir)

        # Check if any component of the path matches an ignore pattern
        path_parts = rel_path.split(os.sep)
        for pattern in self.ignore_patterns:
            # Check the full path
            if fnmatch.fnmatch(rel_path, pattern):
                return True

            # Check each part of the path
            for part in path_parts:
                if fnmatch.fnmatch(part, pattern):
                    return True

        return False

    def is_recent_event(self, event_type, path):
        """
        Check if this event was recently processed to prevent sync loops.

        Args:
            event_type (str): Type of event (created, modified, deleted)
            path (str): Path of the file

        Returns:
            bool: True if this is a duplicate event, False otherwise
        """
        event_key = f"{event_type}:{path}"
        now = datetime.now()

        # Check if we've seen this event recently
        if event_key in recent_events:
            last_time = recent_events[event_key]
            if now - last_time < timedelta(seconds=EVENT_WINDOW):
                return True

        # Update the event timestamp
        recent_events[event_key] = now

        # Clean up old events
        expired_keys = [
            k
            for k, v in recent_events.items()
            if now - v > timedelta(seconds=EVENT_WINDOW * 2)
        ]
        for k in expired_keys:
            del recent_events[k]

        return False

    def get_target_path(self, source_path):
        """
        Get the corresponding path in the target directory.

        Args:
            source_path (str): Path in the source directory

        Returns:
            str: Corresponding path in the target directory
        """
        rel_path = os.path.relpath(source_path, self.source_dir)
        return os.path.join(self.target_dir, rel_path)

    def sync_file(self, src_path):
        """
        Copy a file from source to target, preserving directory structure.

        Args:
            src_path (str): Path of the file to copy
        """
        # Skip if path is a directory or should be ignored
        if os.path.isdir(src_path) or self.should_ignore(src_path):
            return

        # Get the target path
        dest_path = self.get_target_path(src_path)

        # Create target directory if it doesn't exist
        os.makedirs(os.path.dirname(dest_path), exist_ok=True)

        # Copy the file, preserving metadata
        try:
            shutil.copy2(src_path, dest_path)
            rel_path = os.path.relpath(src_path, self.source_dir)
            logger.info(f"Copied: {rel_path} to {self.target_dir}")
        except Exception as e:
            logger.error(f"Error copying {src_path}: {e}")

    def delete_file(self, src_path):
        """
        Delete the corresponding file in the target directory.

        Args:
            src_path (str): Path of the deleted file
        """
        # Skip if path should be ignored
        if self.should_ignore(src_path):
            return

        # Get the target path
        dest_path = self.get_target_path(src_path)

        # Delete the file if it exists
        try:
            if os.path.exists(dest_path):
                if os.path.isdir(dest_path):
                    shutil.rmtree(dest_path)
                else:
                    os.remove(dest_path)
                rel_path = os.path.relpath(src_path, self.source_dir)
                logger.info(f"Deleted: {rel_path} from {self.target_dir}")
        except Exception as e:
            logger.error(f"Error deleting {dest_path}: {e}")

    def on_modified(self, event):
        """Handle file modification events."""
        if not event.is_directory:
            if not self.is_recent_event("modified", event.src_path):
                self.sync_file(event.src_path)

    def on_created(self, event):
        """Handle file creation events."""
        if not self.is_recent_event("created", event.src_path):
            if event.is_directory:
                # Create the directory in the target
                dest_path = self.get_target_path(event.src_path)
                if not os.path.exists(dest_path) and not self.should_ignore(
                    event.src_path
                ):
                    os.makedirs(dest_path, exist_ok=True)
                    rel_path = os.path.relpath(event.src_path, self.source_dir)
                    logger.info(f"Created directory: {rel_path} in {self.target_dir}")
            else:
                self.sync_file(event.src_path)

    def on_deleted(self, event):
        """Handle file deletion events."""
        if not self.is_recent_event("deleted", event.src_path):
            self.delete_file(event.src_path)

    def on_moved(self, event):
        """Handle file move events."""
        if not self.is_recent_event("moved", event.src_path):
            # Handle as a delete followed by a create
            self.delete_file(event.src_path)
            if os.path.exists(event.dest_path):
                self.sync_file(event.dest_path)


def perform_initial_sync(dir1, dir2, ignore_patterns=None):
    """
    Perform an initial sync between two directories.

    Args:
        dir1 (str): First directory
        dir2 (str): Second directory
        ignore_patterns (list): List of patterns to ignore
    """
    logger.info("Performing initial sync...")

    # Sync dir1 to dir2
    handler1 = SyncHandler(dir1, dir2, ignore_patterns)
    for root, dirs, files in os.walk(dir1):
        # Filter out ignored directories to avoid walking them
        dirs[:] = [d for d in dirs if not handler1.should_ignore(os.path.join(root, d))]

        for file in files:
            file_path = os.path.join(root, file)
            if not handler1.should_ignore(file_path):
                handler1.sync_file(file_path)

    # Sync dir2 to dir1
    handler2 = SyncHandler(dir2, dir1, ignore_patterns)
    for root, dirs, files in os.walk(dir2):
        # Filter out ignored directories to avoid walking them
        dirs[:] = [d for d in dirs if not handler2.should_ignore(os.path.join(root, d))]

        for file in files:
            file_path = os.path.join(root, file)
            if not handler2.should_ignore(file_path):
                # Only sync files that don't exist in dir1
                target_path = handler2.get_target_path(file_path)
                if not os.path.exists(target_path):
                    handler2.sync_file(file_path)

    logger.info("Initial sync completed")


def main():
    """Main function to parse arguments and start the file monitoring."""
    parser = argparse.ArgumentParser(
        description="Bidirectional sync between two directories."
    )
    parser.add_argument("dir1", help="First directory to sync")
    parser.add_argument("dir2", help="Second directory to sync")
    parser.add_argument(
        "--ignore",
        nargs="*",
        default=[],
        help="File/directory patterns to ignore (e.g., '*.tmp' '.git')",
    )
    args = parser.parse_args()

    # Validate directories
    for directory in [args.dir1, args.dir2]:
        if not os.path.isdir(directory):
            logger.error(f"Error: Directory '{directory}' does not exist")
            return 1

    # Create directories if they don't exist
    for directory in [args.dir1, args.dir2]:
        os.makedirs(directory, exist_ok=True)

    # Perform initial sync
    perform_initial_sync(args.dir1, args.dir2, args.ignore)

    # Set up the event handlers and observers
    handler1 = SyncHandler(args.dir1, args.dir2, args.ignore)
    handler2 = SyncHandler(args.dir2, args.dir1, args.ignore)

    observer1 = Observer()
    observer1.schedule(handler1, args.dir1, recursive=True)

    observer2 = Observer()
    observer2.schedule(handler2, args.dir2, recursive=True)

    observer1.start()
    observer2.start()

    logger.info("Bidirectional file sync started. Press Ctrl+C to stop.")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("\nStopping file sync...")
        observer1.stop()
        observer2.stop()

    observer1.join()
    observer2.join()
    logger.info("File sync stopped.")
    return 0


if __name__ == "__main__":
    exit(main())
