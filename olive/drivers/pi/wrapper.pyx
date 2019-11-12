#cython: language_level=3

cimport cython

from gcs2 cimport *

@cython.final
cdef class GCS2_Wrapper:
    ##
    ## communication
    ##
    def connect(self):
        return PI_TryConnectUSB("SERIAL")
