#cython: language_level=3

cimport cython

import numpy as np
cimport numpy as np

from gcs2 cimport *

@cython.final
cdef class GCS2:
    """
    Wrapper class for the API.
    """
