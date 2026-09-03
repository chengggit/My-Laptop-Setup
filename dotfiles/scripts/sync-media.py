#!/usr/bin/env python3
import curses
import subprocess
import sys
from pathlib import Path

# CONFIGURATION
PHONE_USER = "heng"
PHONE_IP = "192.168.0.104"
REMOTE_BASE = "/home/heng/media"
MEDIA_ROOT = Path("/run/media/cheng/Media")
CATEGORIES = ["shows", "movies", "Custom Path..."]


def select_category(stdscr):
    """Screen 1: Pick Category or Custom Path."""
    curses.curs_set(0)
    selected_idx = 0

    while True:
        stdscr.clear()
        height, width = stdscr.getmaxyx()

        # Header
        title = " === STEP 1: SELECT DESTINATION CATEGORY === "
        stdscr.addstr(1, 2, title, curses.A_BOLD | curses.A_UNDERLINE)

        # Category List
        for idx, cat in enumerate(CATEGORIES):
            style = curses.A_REVERSE if idx == selected_idx else curses.A_NORMAL
            stdscr.addstr(idx + 3, 4, f" {cat} ", style)

        stdscr.addstr(
            height - 2, 2, "[UP/DOWN]: Navigate | [ENTER]: Select | [ESC]: Quit"
        )
        key = stdscr.getch()

        if key == curses.KEY_UP and selected_idx > 0:
            selected_idx -= 1
        elif key == curses.KEY_DOWN and selected_idx < len(CATEGORIES) - 1:
            selected_idx += 1
        elif key in (10, 13, curses.KEY_ENTER):
            chosen = CATEGORIES[selected_idx]
            if chosen == "Custom Path...":
                return get_custom_path(stdscr)
            return chosen
        elif key == 27:  # ESC
            return None


def get_custom_path(stdscr):
    """Sub-screen: Prompt user to type a custom remote path."""
    curses.echo()
    curses.curs_set(1)
    stdscr.clear()
    stdscr.addstr(
        2,
        2,
        "Type custom remote path on phone (e.g. /home/media/downloads):",
        curses.A_BOLD,
    )
    stdscr.addstr(4, 2, "> ")

    input_bytes = stdscr.getstr(4, 4, 100)
    curses.noecho()
    curses.curs_set(0)

    path_str = input_bytes.decode("utf-8").strip()
    return path_str if path_str else None


def file_picker(stdscr, start_dir):
    """Screen 2: Multi-selection Interactive File/Directory Browser."""
    curses.curs_set(0)
    current_dir = Path(start_dir).expanduser().resolve()
    if not current_dir.exists():
        current_dir = Path.home()

    selected_indices = set()
    current_idx = 0

    while True:
        stdscr.clear()
        height, width = stdscr.getmaxyx()

        # Build directory listing
        try:
            raw_items = sorted(
                list(current_dir.iterdir()),
                key=lambda x: (not x.is_dir(), x.name.lower()),
            )
        except PermissionError:
            raw_items = []

        items = [Path("..")] + raw_items

        # Bounds check for cursor index
        if current_idx >= len(items):
            current_idx = max(0, len(items) - 1)

        # Header bar
        header = f" Browse: {current_dir} "
        stdscr.addstr(0, 0, header[: width - 1], curses.A_REVERSE | curses.A_BOLD)

        # Instructions footer
        footer = " [SPACE]: Toggle Check [X] | [ENTER]: Confirm Selection/Enter Dir | [ESC]: Cancel "
        stdscr.addstr(height - 1, 0, footer[: width - 1], curses.A_REVERSE)

        # Render file list with pagination
        visible_rows = height - 3
        start_idx = max(
            0, min(current_idx - visible_rows // 2, max(0, len(items) - visible_rows))
        )

        for row, item in enumerate(items[start_idx : start_idx + visible_rows]):
            actual_idx = start_idx + row
            y = row + 1

            if item.name == "..":
                display_name = "⬆️  .. (Go Up / Select Current Folder)"
            else:
                is_checked = actual_idx in selected_indices
                check_str = "[X] " if is_checked else "[ ] "
                icon = "📁 " if item.is_dir() else "📄 "
                display_name = f"{check_str}{icon}{item.name}"

            style = (
                curses.A_REVERSE | curses.A_BOLD
                if actual_idx == current_idx
                else curses.A_NORMAL
            )
            stdscr.addstr(y, 2, display_name[: width - 4], style)

        stdscr.refresh()
        key = stdscr.getch()

        # Navigation & Selection
        if key == curses.KEY_UP and current_idx > 0:
            current_idx -= 1
        elif key == curses.KEY_DOWN and current_idx < len(items) - 1:
            current_idx += 1
        elif key == ord(" "):  # SPACEBAR: Toggle selection checkmark
            if current_idx == 0:
                # Highlighted ".." -> return current directory as whole
                return [current_dir]
            if current_idx in selected_indices:
                selected_indices.remove(current_idx)
            else:
                selected_indices.add(current_idx)
        elif key in (10, 13, curses.KEY_ENTER):  # ENTER
            if selected_indices:
                return [items[i] for i in selected_indices]

            selected_item = items[current_idx]
            if selected_item.name == "..":
                if current_dir != current_dir.parent:
                    current_dir = current_dir.parent
                    current_idx = 0
                    selected_indices.clear()
            elif selected_item.is_dir():
                current_dir = selected_item
                current_idx = 0
                selected_indices.clear()
            else:
                # Single file fallback if spacebar wasn't used
                return [selected_item]
        elif key == 27:  # ESC to cancel
            return None


def run_tui(stdscr):
    category = select_category(stdscr)
    if not category:
        return None, None

    selected_paths = file_picker(stdscr, MEDIA_ROOT)
    if not selected_paths:
        return None, None

    return category, selected_paths


def main():
    category, selected_paths = curses.wrapper(run_tui)

    if not category or not selected_paths:
        print("\nSelection canceled.")
        sys.exit(0)

    # Determine remote folder path safely
    first_path = selected_paths[0]
    if category.startswith("/"):
        remote_target = category
    else:
        # If user picked a directory directly or multi-selected items inside a show folder
        folder_name = (
            first_path.name
            if (len(selected_paths) == 1 and first_path.is_dir())
            else first_path.parent.name
        )
        remote_target = f"{REMOTE_BASE}/{category}/{folder_name}"

    print("\n" + "=" * 60)
    print(f" Syncing {len(selected_paths)} item(s)")
    print(f" Destination: {PHONE_USER}@{PHONE_IP}:{remote_target}")
    print("=" * 60 + "\n")

    # Step 1: Ensure directory structure on phone
    print("==> Creating directory structure on phone...")
    mkdir_cmd = [
        "ssh",
        f"{PHONE_USER}@{PHONE_IP}",
        f'mkdir -p "{remote_target}"',
    ]

    res = subprocess.run(mkdir_cmd)
    if res.returncode != 0:
        print("\nFailed to create remote directory!")
        sys.exit(1)

    # Step 2: Sync each selected file/folder with forced permissions
    print("==> Starting file transfer:\n")
    for path in selected_paths:
        rsync_src = f"{path}/" if path.is_dir() else str(path)
        rsync_dst = f"{PHONE_USER}@{PHONE_IP}:{remote_target}/"

        rsync_cmd = [
            "rsync",
            "-Pavu",
            "--info=progress2",
            rsync_src,
            rsync_dst,
        ]

        print(f"==> Transferring: {path.name}")
        try:
            subprocess.run(rsync_cmd, check=True)
        except subprocess.CalledProcessError as e:
            print(f"\n❌ Transfer failed on {path.name} with code {e.returncode}")
            sys.exit(e.returncode)

    print("\n✅ Sync completed successfully!")


if __name__ == "__main__":
    main()

