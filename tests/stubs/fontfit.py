#!/usr/bin/env python3
# test stub for lib/fontfit.py: the size it was given, or $T_FONTFIT_TO
import os, sys
print(os.environ.get("T_FONTFIT_TO") or sys.argv[2])
