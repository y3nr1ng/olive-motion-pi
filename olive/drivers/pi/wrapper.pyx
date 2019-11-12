#cython: language_level=3

from cpython cimport bool as pybool
cimport cython
from cython cimport view

from gcs2 cimport *

@cython.final
cdef class GCS2:
    ##
    ## communication
    ##
    ## rs232
    def try_connect_rs232(self):
        pass

    def connect_rs232(self, port_num, baudrate, name):
        pass

    def open_rs232_daisy_chain(self):
        pass

    ## usb
    cpdef enumerate_usb(self, str keyword, int nbytes=8192):
        cdef char[::1] buffer = view.array(shape=(nbytes, ), itemsize=sizeof(char), format='c')
        cdef char *c_buffer = &buffer[0]

        PI_EnumerateUSB(c_buffer, nbytes, keyword.encode())

        return buffer.decode('utf-8', errors='replace')

    def try_connect_usb(self):
        pass

    def connect_usb(self, desc, baudrate=None):
        pass

    def open_usb_daisy_chain(self):
        pass

    ## daisy chain
    def connect_daisy_chain_device(self, port_id, device_num):
        pass

    def close_daisy_chain(self, port_id):
        pass

    ## probe
    def is_connected(self, ctrl_id):
        pass

    def is_connecting(self, ctrl_id):
        pass

    ## termination
    def cancel_connect(self, thread_id):
        pass

    def close_connection(self, ctrl_id):
        pass


    ## probe
    cpdef set_error_check(self, int ctrl_id, pybool err_check):
        PI_SetErrorCheck(ctrl_id, err_check)

    def get_controller_id(self, thread_id):
        pass

    def get_error(self, ctrl_id):
        pass

    def translate_error(self, err):
        pass




