#cython: language_level=3

from cpython cimport bool as pybool
cimport cython
from cython cimport view
from libcpp.vector cimport vector

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
        return status > 0

    cpdef get_controller_id(self, int thread_id):
        ret = PI_GetControllerID(thread_id)
        Communication.check_error(ret)
        return ret

    cpdef is_connected(self, int ctrl_id):
        ret = PI_IsConnected(ctrl_id)
        return ret > 0

    ### daisy chain ###
    cpdef set_daisy_chain_scan_max_device_id(self, int max_id):
        ret = PI_SetDaisyChainScanMaxDeviceID(max_id)
        Communication.check_error(ret)

    cpdef open_usb_daisy_chain(self, str desc, int nbytes=1024):
        """
        Open a USB interface to a daisy chain.

        Note that calling this function does not open a daisy chain device, to get access to one, one must call `connect_daisy_chain_device` later on.

        Args:
            desc (str): description of the controller
            nbytes (int, optional): size of the buffer to receive IDN
        """
        cdef char[::1] buffer = view.array(
            shape=(nbytes, ), itemsize=sizeof(char), format='c'
        )
        cdef char *c_buffer = &buffer[0]

        b_desc = desc.encode('ascii')
        cdef char *c_desc = b_desc

        cdef int n_dev
        ret = PI_OpenUSBDaisyChain(c_desc, &n_dev, c_buffer, nbytes)
        Communication.check_error(ret)

        return ret, n_dev, c_buffer.decode('ascii', errors='replace')

    cpdef connect_daisy_chain_device(self, int daisy_id, int index):
        """
        Open a daisy chain device.

        Before connecting a daisy cahin device, the daisy chain port has to be opened using `open_usb_daisy_chain`.

        Args:
            daisy_id (int): ID of the daisy chain port
            index (int): index of the daisy chain device to use, [1, N]
        """
        ret = PI_ConnectDaisyChainDevice(daisy_id, index)
        Communication.check_error(ret)
        return ret

    cpdef close_daisy_chain(self, daisy_id):
        PI_CloseDaisyChain(daisy_id)

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
        raise RuntimeError(translate_error(err_id))

    ##

    cpdef set_error_check(self, pybool err_check):
        PI_SetErrorCheck(self.ctrl_id, err_check)

    ## query status ##
    cpdef is_moving(self, str axes=""):
        """#5"""
        b_axes = axes.encode('ascii')
        cdef char *c_axes = b_axes

        cdef int status
        ret = PI_IsMoving(self.ctrl_id, c_axes, &status)
        self.check_error(ret)
        return status > 0

    cpdef is_controller_ready(self):
        """#7"""
        cdef int status
        ret = PI_IsControllerReady(self.ctrl_id, &status)
        self.check_error(ret)
        return status > 0

    cpdef is_running_macro(self):
        """#8"""
        cdef int status
        ret = PI_IsRunningMacro(self.ctrl_id, &status)
        self.check_error(ret)
        return status > 0

    ## axis control ##
    cpdef get_axes_enable_status(self, str axes):
        """qEAX"""
        pass

    cpdef set_axes_enable_status(self, str axes, pybool state):
        """EAX"""
        pass

    cpdef get_axes_id(self, pybool include_deactivated=True, int nbytes=512):
        """qSAI/qSAI_ALL"""
        cdef char[::1] buffer = view.array(
            shape=(nbytes, ), itemsize=sizeof(char), format='c'
        )
        cdef char *c_buffer = &buffer[0]

        if include_deactivated:
            ret = PI_qSAI_ALL(self.ctrl_id, c_buffer, nbytes)
        else:
            ret = PI_qSAI(self.ctrl_id, c_buffer, nbytes)
        self.check_error(ret)

        return c_buffer.decode('ascii', errors='replace')

    cpdef get_stage_type(self, str axis_id="", int nbytes=512):
        """qCST"""
        cdef char[::1] buffer = view.array(
            shape=(nbytes, ), itemsize=sizeof(char), format='c'
        )
        cdef char *c_buffer = &buffer[0]

        b_axis_id = axis_id.encode('ascii')
        cdef char *c_axis_id = b_axis_id
        ret = PI_qCST(self.ctrl_id, c_axis_id, c_buffer, nbytes)
        self.check_error(ret)

        return c_buffer.decode('ascii', errors='replace')

    cpdef get_axes_parameter(
        self, str axis_id, parameter, pybool volatile=False, int nbytes=512
    ):
        """qSEP/qSPA"""
        b_axis_id = axis_id.encode('ascii')
        cdef char *c_axis_id = b_axis_id

        cdef vector[unsigned int] v_parameter = parameter

        cdef double[::1] value = view.array(
            shape=(nbytes, ), itemsize=sizeof(double), format='g'
        )
        cdef double *c_value = &value[0]

        cdef char[::1] strings = view.array(
            shape=(nbytes, ), itemsize=sizeof(char), format='c'
        )
        cdef char *c_strings = &strings[0]

        if volatile:
            ret = PI_qSPA(
                self.ctrl_id,
                c_axis_id,
                v_parameter.data(),
                c_value,
                c_strings,
                nbytes
            )
        else:
            ret = PI_qSEP(
                self.ctrl_id,
                c_axis_id,
                v_parameter.data(),
                c_value,
                c_strings,
                nbytes
            )
        self.check_error(ret)

        return value, c_strings.decode('ascii', errors='replace')

    cpdef set_axes_parameter(self):
        pass

    ## motions ##
    cpdef go_to_home(self, str axes=""):
        """GOH"""
        b_axes = axes.encode('ascii')
        cdef char *c_axes = b_axes

        cdef int status
        ret = PI_GOH(self.ctrl_id, c_axes)
        self.check_error(ret)

    cpdef halt(self, str axes):
        """HALT"""
        pass

    ## utils ##
    cpdef get_available_commands(self, int nbytes=512):
        """qHLP"""
        cdef char[::1] buffer = view.array(
            shape=(nbytes, ), itemsize=sizeof(char), format='c'
        )
        cdef char *c_buffer = &buffer[0]

        ret = PI_qHLP(self.ctrl_id, c_buffer, nbytes)
        self.check_error(ret)

        return c_buffer.decode('ascii', errors='replace')

    cpdef get_identification_string(self, int nbytes=256):
        """qIDN"""
        cdef char[::1] buffer = view.array(
            shape=(nbytes, ), itemsize=sizeof(char), format='c'
        )
        cdef char *c_buffer = &buffer[0]

        ret = PI_qIDN(self.ctrl_id, c_buffer, nbytes)
        self.check_error(ret)

        return c_buffer.decode('ascii', errors='replace')

    cpdef get_available_parameters(self, int nbytes=512):
        """qHPA"""
        cdef char[::1] buffer = view.array(
            shape=(nbytes, ), itemsize=sizeof(char), format='c'
        )
        cdef char *c_buffer = &buffer[0]

        ret = PI_qHPA(self.ctrl_id, c_buffer, nbytes)
        self.check_error(ret)

        return c_buffer.decode('ascii', errors='replace')

    cpdef get_valid_character_set(self, int nbytes=512):
        """qTVI"""
        cdef char[::1] buffer = view.array(
            shape=(nbytes, ), itemsize=sizeof(char), format='c'
        )
        cdef char *c_buffer = &buffer[0]

        ret = PI_qTVI(self.ctrl_id, c_buffer, nbytes)
        self.check_error(ret)

        return c_buffer.decode('ascii', errors='replace')

    cpdef get_version(self, int nbytes=512):
        """qVER"""
        cdef char[::1] buffer = view.array(
            shape=(nbytes, ), itemsize=sizeof(char), format='c'
        )
        cdef char *c_buffer = &buffer[0]

        ret = PI_qVER(self.ctrl_id, c_buffer, nbytes)
        self.check_error(ret)

        return c_buffer.decode('ascii', errors='replace')
