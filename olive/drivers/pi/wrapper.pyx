#cython: language_level=3

from cpython cimport bool as pybool
cimport cython
from cython cimport view

from gcs2 cimport *

cdef translate_error(int err_id, int nbytes=1024):
    cdef char[::1] buffer = view.array(
        shape=(nbytes, ), itemsize=sizeof(char), format='c'
    )
    cdef char *c_buffer = &buffer[0]

    ret = PI_TranslateError(err_id, c_buffer, nbytes)
    assert ret > 0, f"message buffer ({nbytes} bytes) is too small"

    return c_buffer.decode('ascii', errors='replace')

@cython.final
cdef class Communication:
    ##
    ## error
    ##
    @staticmethod
    cdef check_error(int ret):
        if ret < 0:
            print(f'err_id: {ret}')
            raise RuntimeError(translate_error(ret))

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

    cpdef connect_usb(self, str desc, int baudrate=-1):
        b_desc = desc.encode('ascii')
        cdef char *c_desc = b_desc

        if baudrate < 0:
            ret = PI_ConnectUSB(c_desc)
        else:
            ret = PI_ConnectUSBWithBaudRate(c_desc, baudrate)
        Communication.check_error(ret)

        return ret

    ### async connection ###
    cpdef try_connect_usb(self, str desc):
        b_desc = desc.encode('ascii')
        cdef char *c_desc = b_desc

        ret = PI_TryConnectUSB(c_desc)
        Communication.check_error(ret)

        return ret

    cpdef is_connecting(self, int thread_id):
        cdef int status
        ret = PI_IsConnecting(thread_id, &status)
        Communication.check_error(ret)
        return <pybool>(status > 0)

    cpdef get_controller_id(self, int thread_id):
        ret = PI_GetControllerID(thread_id)
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
        if ret > 0:
            # true, successful
            return
        err_id = PI_GetError(self.ctrl_id)
        print(f'ctrl_id: {self.ctrl_id}, err_id: {err_id}')
        raise RuntimeError(translate_error(err_id))

    ##

    cpdef set_error_check(self, int ctrl_id, pybool err_check):
        PI_SetErrorCheck(ctrl_id, err_check)

    ##

    cpdef get_help(self, int nbytes=1024):
        """qHLP"""
        cdef char[::1] buffer = view.array(
            shape=(nbytes, ), itemsize=sizeof(char), format='c'
        )
        cdef char *c_buffer = &buffer[0]

        ret = PI_qHLP(self.ctrl_id, c_buffer, nbytes)
        self.check_error(ret)

        return c_buffer.decode('ascii', errors='replace')

    cpdef get_serial_number(self, int nbytes=64):
        """qSSN"""
        cdef char[::1] buffer = view.array(
            shape=(nbytes, ), itemsize=sizeof(char), format='c'
        )
        cdef char *c_buffer = &buffer[0]

        ret = PI_qSSN(self.ctrl_id, c_buffer, nbytes)
        self.check_error(ret)

        for b in buffer:
            print(b, end=' ')
        print()

        return c_buffer.decode('ascii', errors='replace')

    cpdef get_version(self, int nbytes=16384):
        """qVER"""
        cdef char[::1] buffer = view.array(
            shape=(nbytes, ), itemsize=sizeof(char), format='c'
        )
        cdef char *c_buffer = &buffer[0]

        ret = PI_qVER(self.ctrl_id, c_buffer, nbytes)
        self.check_error(ret)

        print(buffer)

        return c_buffer.decode('ascii', errors='replace')
