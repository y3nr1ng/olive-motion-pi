#cython: language_level=3

from cpython cimport bool as pybool
cimport cython
from cython cimport view

from gcs2 cimport *

@cython.final
cdef class GCS2:
    ##
    ## error
    ##
    @staticmethod
    def check_error(int ret):
        if ret < 0:
            msg = GCS2.translate_error(ret)


    @staticmethod
    cdef get_error(int ctrl_id):
        return PI_GetError(ctrl_id)

    @staticmethod
    cdef translate_error(int errno, int nbytes=1024):
        cdef char[::1] buffer = view.array(shape=(nbytes, ), itemsize=sizeof(char), format='c')
        cdef char *c_buffer = &buffer[0]

        ret = PI_TranslateError(errno, c_buffer, nbytes)
        assert ret > 0, f"message buffer ({nbytes} bytes) is too small"

        return c_buffer.decode('ascii', errors='replace')

    cpdef set_error_check(self, int ctrl_id, pybool err_check):
        PI_SetErrorCheck(ctrl_id, err_check)

    ##
    ## communication
    ##
    ### USB ###
    cpdef enumerate_usb(self, str keyword=None, int nbytes=1024):
        cdef char[::1] buffer = view.array(shape=(nbytes, ), itemsize=sizeof(char), format='c')
        cdef char *c_buffer = &buffer[0]

        b_keyword = keyword.encode('ascii')
        cdef char *c_keyword = b_keyword

        ret = PI_EnumerateUSB(c_buffer, nbytes, c_keyword)

        return c_buffer.decode('ascii', errors='replace')

    def try_connect_usb(self, str desc):
        b_desc = desc.encode('ascii')
        cdef char *c_desc = b_desc

        ret = PI_TryConnectUSB(c_desc)

        return ret

    def connect_usb(self, desc, baudrate=None):
        pass

    ### termination ###
    def close_connection(self, ctrl_id):
        pass
