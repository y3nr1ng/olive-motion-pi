#cython: language_level=3

from cpython cimport bool as pybool
cimport cython
from cython cimport view

from gcs2 cimport *

@cython.final
cdef class Communication:
    ##
    ## error
    ##
    @staticmethod
    cdef check_error(int ret):
        if ret < 0:
            raise RuntimeError(Communication.translate_error(ret))

    @staticmethod
    cdef translate_error(int err_id, int nbytes=1024):
        cdef char[::1] buffer = view.array(
            shape=(nbytes, ), itemsize=sizeof(char), format='c'
        )
        cdef char *c_buffer = &buffer[0]

        ret = PI_TranslateError(err_id, c_buffer, nbytes)
        assert ret > 0, f"message buffer ({nbytes} bytes) is too small"

        return c_buffer.decode('ascii', errors='replace')

    ##
    ## communication
    ##
    ### USB ###
    cpdef enumerate_usb(self, str keyword="", int nbytes=1024):
        cdef char[::1] buffer = view.array(
            shape=(nbytes, ), itemsize=sizeof(char), format='c'
        )
        cdef char *c_buffer = &buffer[0]

        b_keyword = keyword.encode('ascii')
        cdef char *c_keyword = b_keyword

        ret = PI_EnumerateUSB(c_buffer, nbytes, c_keyword)
        Communication.check_error(ret)

        return c_buffer.decode('ascii', errors='replace')

    cpdef try_connect_usb(self, str desc):
        b_desc = desc.encode('ascii')
        cdef char *c_desc = b_desc

        ret = PI_TryConnectUSB(c_desc)
        Communication.check_error(ret)

        return ret

    cpdef connect_usb(self, str desc, int baudrate=-1):
        b_desc = desc.encode('ascii')
        cdef char *c_desc = b_desc

        if baudrate < 0:
            ret = PI_ConnectUSB(c_desc)
        else:
            ret = PI_ConnectUSBWithBaudRate(c_desc, baudrate)
        Communication.check_error(ret)

        return ret

    ### termination ###
    cpdef close_connection(self, int ctrl_id):
        PI_CloseConnection(ctrl_id)


@cython.final
cdef class Command:
    """
    Wrapper class for GCS2 commands. These commands are controller dependents.
    """
    cdef readonly int ctrl_id

    def __cinit__(self, int ctrl_id):
        self.ctrl_id = ctrl_id

    cdef check_error(self, int ret):
        if ret <= 0:
            err_id = PI_GetError(self.ctrl_id)
            raise RuntimeError(Communication.translate_error(err_id))

    ##

    cpdef set_error_check(self, int ctrl_id, pybool err_check):
        PI_SetErrorCheck(ctrl_id, err_check)