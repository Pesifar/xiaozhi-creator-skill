#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pathlib import Path
import runpy


def main() -> None:
    root_script = Path(__file__).resolve().parents[1] / "create_agent.py"
    runpy.run_path(str(root_script), run_name="__main__")


if __name__ == "__main__":
    main()

