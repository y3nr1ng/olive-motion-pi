import os
import sys

# expand library search path on windows
if not sys.platform.startswith("linux"):
    os.environ["PATH"] += os.pathsep + os.path.join(
        os.path.abspath(os.path.dirname(__file__)), "lib"
    )

from .generic import *
