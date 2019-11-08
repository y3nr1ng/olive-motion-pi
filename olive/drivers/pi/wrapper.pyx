#cython: language_level=3

from cpython cimport bool as pybool
from cpython cimport buffer
from cpython.exc cimport PyErr_SetFromErrnoWithFilenameObject
cimport cython
from cython cimport view
from cython.view cimport memoryview
from libc.stdint cimport uint8_t, uintptr_t
from libc.stdlib cimport malloc, free
from libc.string cimport memset, strcmp

from enum import auto, Enum, IntEnum

import numpy as np
cimport numpy as np

from dcamapi cimport *
from dcamprop cimport *

##
## Driver
##
class Capability(Enum):
    LUT         = auto()
    Region      = auto()
    FrameOption = auto()

class CaptureStatus(IntEnum):
    Error       = DCAMCAP_STATUS.DCAMCAP_STATUS_ERROR
    Busy        = DCAMCAP_STATUS.DCAMCAP_STATUS_BUSY
    Ready       = DCAMCAP_STATUS.DCAMCAP_STATUS_READY
    Stable      = DCAMCAP_STATUS.DCAMCAP_STATUS_STABLE
    Unstable    = DCAMCAP_STATUS.DCAMCAP_STATUS_UNSTABLE

class CaptureType(IntEnum):
    Sequence    = DCAMCAP_START.DCAMCAP_START_SEQUENCE
    Snap        = DCAMCAP_START.DCAMCAP_START_SNAP

class Event(IntEnum):
    """Capture events"""
    Transferred = DCAMWAIT_EVENT.DCAMWAIT_CAPEVENT_TRANSFERRED
    FrameReady  = DCAMWAIT_EVENT.DCAMWAIT_CAPEVENT_FRAMEREADY
    CycleEnd    = DCAMWAIT_EVENT.DCAMWAIT_CAPEVENT_CYCLEEND
    ExposureEnd = DCAMWAIT_EVENT.DCAMWAIT_CAPEVENT_EXPOSUREEND
    Stopped     = DCAMWAIT_EVENT.DCAMWAIT_CAPEVENT_STOPPED

class Info(IntEnum):
    Bus             = DCAM_IDSTR.DCAM_IDSTR_BUS
    CameraID        = DCAM_IDSTR.DCAM_IDSTR_CAMERAID
    Vendor          = DCAM_IDSTR.DCAM_IDSTR_VENDOR
    Model           = DCAM_IDSTR.DCAM_IDSTR_MODEL
    CameraVersion   = DCAM_IDSTR.DCAM_IDSTR_CAMERAVERSION
    DriverVersion   = DCAM_IDSTR.DCAM_IDSTR_DRIVERVERSION
    ModuleVersion   = DCAM_IDSTR.DCAM_IDSTR_MODULEVERSION
    APIVersion      = DCAM_IDSTR.DCAM_IDSTR_DCAMAPIVERSION

class Unit(IntEnum):
    Second          = DCAMPROPUNIT.DCAMPROP_UNIT_SECOND
    Celsius         = DCAMPROPUNIT.DCAMPROP_UNIT_CELSIUS
    Kelvin          = DCAMPROPUNIT.DCAMPROP_UNIT_KELVIN
    MeterPerSecond  = DCAMPROPUNIT.DCAMPROP_UNIT_METERPERSECOND
    PerSecond       = DCAMPROPUNIT.DCAMPROP_UNIT_PERSECOND
    Degree          = DCAMPROPUNIT.DCAMPROP_UNIT_DEGREE
    MicroMeter      = DCAMPROPUNIT.DCAMPROP_UNIT_MICROMETER
    Unitless        = DCAMPROPUNIT.DCAMPROP_UNIT_NONE

@cython.final
cdef class DCAMAPI:
    """
    Wrapper class for the API.

    DCAM-API can ONLY INSTANTIATE ONCE.
    """
    #: number of supported devices found by DCAM-API
    cdef readonly int32 n_devices

    def init(self):
        """
        Initialize the DCAM-API manager, modules and drivers.

        Only one session of DCAM-API can be open at any time, therefore, DCAMAPI wrapped _DCAMAPI, who provides the singleton behavior.
        """
        cdef DCAMAPI_INIT apiinit
        memset(&apiinit, 0, sizeof(apiinit))
        apiinit.size = sizeof(apiinit)

        cdef DCAMERR err
        err = dcamapi_init(&apiinit)
        DCAMAPI.check_error(err, 'dcamapi_init()')

        self.n_devices = apiinit.iDeviceCount

    def  uninit(self):
        """
        Cleanups all resources and objects used by DCAM-API.

        All opened devices will be forcefully closed. No new devices can be opened unless initialize again.
        """
        dcamapi_uninit()

    ##

    cpdef open(self, int32 index):
        cdef DCAMDEV_OPEN devopen
        memset(&devopen, 0, sizeof(devopen))
        devopen.size = sizeof(devopen)
        devopen.index = index

        cdef DCAMERR err
        err = dcamdev_open(&devopen)
        DCAMAPI.check_error(err, 'dcamdev_open()')

        return <object>devopen.hdcam

    cpdef close(self, DCAM dev):
        cdef DCAMERR err

        err = dcamdev_close(dev.handle)
        DCAMAPI.check_error(err, 'dcamdev_close()')

    ##

    @staticmethod
    cdef check_error(DCAMERR errid, const char* apiname, HDCAM hdcam=NULL, int32 nbytes=256):
        if not failed(errid):
            return

        # implicit string reader for fast access
        cdef char[::1] errtext = view.array(shape=(nbytes, ), itemsize=sizeof(char), format='c')
        cdef char *c_errtext = &errtext[0]

        cdef DCAMDEV_STRING param
        memset(&param, 0, sizeof(param))
        param.size = sizeof(param)
        param.text = c_errtext
        param.textbytes = nbytes
        param.iString = errid
        dcamdev_getstring(hdcam, &param)

        # restrict errid to 32-bits to match C-style output
        raise RuntimeError(
            f"{apiname.decode('utf-8')}, (DCAMERR)0x{errid&0xFFFFFFFF:08X} {c_errtext.decode('utf-8')}"
        )

@cython.final
cdef class DCAMWAIT:
    cdef HDCAM hdcam
    cdef HDCAMWAIT handle

    def __cinit__(self, uintptr_t hdcam):
        self.hdcam = <HDCAM>hdcam

    def open(self):
        """
        Create the HDCAMWAIT handle for a HDCAM member.
        """
        cdef DCAMWAIT_OPEN waitopen
        memset(&waitopen, 0, sizeof(waitopen))
        waitopen.size = sizeof(waitopen)
        waitopen.hdcam = self.hdcam

        err = dcamwait_open(&waitopen)
        DCAMAPI.check_error(err, 'dcamwait_open()', self.hdcam)

        self.handle = waitopen.hwait

    def close(self):
        """
        Release the HDCAMWAIT handle.
        """
        cdef DCAMERR err
        err = dcamwait_close(self.handle)
        DCAMAPI.check_error(err, 'dcamwait_close()', self.hdcam)

        # ensure it is empty
        self.handle = <HDCAMWAIT>0

    cpdef start(self, int32 event: Event, int32 timeout=1000):
        """
        Start waiting for a specified DCAM event.

        Args:
            event (Event): type of event to wait
            timeout (int): this function will wait as maximum by miliseconds
        """
        cdef DCAMWAIT_START waitstart
        memset(&waitstart, 0, sizeof(waitstart))
        waitstart.size = sizeof(waitstart)
        waitstart.eventmask = event
        waitstart.timeout = timeout

        cdef DCAMERR err
        err = dcamwait_start(self.handle, &waitstart)
        DCAMAPI.check_error(err, 'dcamwait_start()', self.hdcam)

    def abort(self):
        """
        Aborts a start() call.
        """
        cdef DCAMERR err
        err = dcamwait_abort(self.handle)
        DCAMAPI.check_error(err, 'dcamwait_abort()', self.hdcam)

@cython.final
cdef class DCAM:
    """Base class for the device."""
    cdef HDCAM handle
    cdef uintptr_t[::1] buffer

    def __cinit__(self, handle):
        self.handle = <HDCAM>handle

    ##
    ## device data
    ##
    def get_capability(self, capability: Capability):
        """Returns capability information not able to get from property."""
        try:
            return {
                Capability.Region: self._get_capability_region,
                Capability.LUT: self._get_capability_lut,
                Capability.FrameOption: self._get_capability_frameoption
            }[capability]()
        except KeyError:
            raise ValueError('unknown capability option')

    def _get_capability_region(self):
        cdef DCAMDEV_CAPABILITY_REGION param
        memset(&param, 0, sizeof(param))
        param.hdr.size = sizeof(param)
        param.hdr.domain = DCAMDEV_CAPDOMAIN.DCAMDEV_CAPDOMAIN__DCAMDATA
        param.hdr.kind = DCAMDATA_KIND.DCAMDATA_KIND__REGION

        cdef DCAMERR err
        err = dcamdev_getcapability(self.handle, &param.hdr)
        try:
            DCAMAPI.check_error(err, 'dcamdev_getcapbility()', self.handle)
        except RuntimeError:
            raise RuntimeError("does not support region")

        attributes = dict()
        attributes['units'] = {'horizontal': param.horzunit, 'vertical': param.vertunit}

        region_type = param.hdr.capflag & DCAMDATA_REGIONTYPE.DCAMDATA_REGIONTYPE__BODYMASK
        attributes['type'] = []
        if region_type == DCAMDATA_REGIONTYPE.DCAMDATA_REGIONTYPE__NONE:
            attributes['type'] = 'none'
        else:
            if region_type == DCAMDATA_REGIONTYPE.DCAMDATA_REGIONTYPE__RECT16ARRAY:
                attributes['type'].append('rect16array')
            if region_type == DCAMDATA_REGIONTYPE.DCAMDATA_REGIONTYPE__BYTEMASK:
                attributes['type'].append('bytemask')

        return attributes

    def _get_capability_lut(self):
        cdef DCAMDEV_CAPABILITY_LUT param
        memset(&param, 0, sizeof(param))
        param.hdr.size = sizeof(param)
        param.hdr.domain = DCAMDEV_CAPDOMAIN.DCAMDEV_CAPDOMAIN__DCAMDATA
        param.hdr.kind = DCAMDATA_KIND.DCAMDATA_KIND__LUT

        cdef DCAMERR err
        err = dcamdev_getcapability(self.handle, &param.hdr)
        DCAMAPI.check_error(err, 'dcamdev_getcapbility()', self.handle)

        attributes = dict()

        lut_type = param.hdr.capflag & DCAMDATA_LUTTYPE.DCAMDATA_LUTTYPE__BODYMASK
        if lut_type == DCAMDATA_LUTTYPE.DCAMDATA_LUTTYPE__NONE:
            attributes['type'] = 'none'
        elif lut_type == DCAMDATA_LUTTYPE.DCAMDATA_LUTTYPE__SEGMENTED_LINEAR:
            attributes['type'] = 'linear'
            attributes['max_points'] = param.linearpointmax
        else:
            attributes['type'] = 'unknown'

        return attributes

    def _get_capability_frameoption(self):
        cdef DCAMDEV_CAPABILITY_FRAMEOPTION param
        memset(&param, 0, sizeof(param))
        param.hdr.size = sizeof(param)
        param.hdr.domain = DCAMDEV_CAPDOMAIN.DCAMDEV_CAPDOMAIN__FRAMEOPTION

        cdef DCAMERR err
        err = dcamdev_getcapability(self.handle, &param.hdr)
        DCAMAPI.check_error(err, 'dcamdev_getcapbility()', self.handle)

        if param.supportproc == 0:
            raise RuntimeError("does not support processing options")
        if param.hdr.capflag == 0:
            raise RuntimeError('frame option is currently disabled')

        flags = {
            'highcontrast': DCAMBUF_PROCTYPE.DCAMBUF_PROCTYPE__HIGHCONTRASTMODE
        }
        return {
            key: <pybool>(param.hdr.capflag & value)
            for key, value in flags.items()
        }

    cpdef get_string(self, int32 idstr, int32 nbytes=256):
        cdef char[::1] text = view.array(shape=(nbytes, ), itemsize=sizeof(char), format='c')
        cdef char *c_text = &text[0]

        cdef DCAMDEV_STRING param
        memset(&param, 0, sizeof(param))
        param.size = sizeof(param)
        param.text = c_text
        param.textbytes = nbytes
        param.iString = idstr

        dcamdev_getstring(self.handle, &param)
        return c_text.decode('utf-8', errors='replace')

    def set_data(self):
        """
        Set the data that is impossible to set with property. WTF?
        """
        pass

    def get_data(self):
        """
        Get the data that is impossible to get from property. WTF!?
        """
        pass
    ##
    ## device data
    ##

    ##
    ## property control
    ##
    cpdef get_attr(self, int32 iprop):
        cdef DCAMPROP_ATTR attr
        memset(&attr, 0, sizeof(attr))
        attr.cbSize	= sizeof(attr)
        attr.iProp	= iprop

        cdef DCAMERR err
        err = dcamprop_getattr(self.handle, &attr)
        DCAMAPI.check_error(err, 'dcamprop_getattr()', self.handle)

        attributes = dict()

        # read/write
        attributes = {
            'writable': pybool(attr.attribute & DCAMPROPATTRIBUTE.DCAMPROP_ATTR_WRITABLE),
            'readable': pybool(attr.attribute & DCAMPROPATTRIBUTE.DCAMPROP_ATTR_READABLE),
        }

        # type
        prop_type = attr.attribute & DCAMPROPATTRIBUTE.DCAMPROP_TYPE_MASK
        if prop_type == DCAMPROPATTRIBUTE.DCAMPROP_TYPE_MODE:
            attributes['type'] = 'mode'
        elif prop_type == DCAMPROPATTRIBUTE.DCAMPROP_TYPE_LONG:
            attributes['type'] = 'long'
        elif prop_type == DCAMPROPATTRIBUTE.DCAMPROP_TYPE_REAL:
            attributes['type'] = 'real'
        else:
            raise RuntimeError('unknown attribute type')

        # unit
        attributes['unit'] = Unit(attr.iUnit)

        # array
        prop_type = attr.attribute2 & DCAMPROPATTRIBUTE2.DCAMPROP_ATTR2_ARRAYBASE
        is_array = prop_type == DCAMPROPATTRIBUTE2.DCAMPROP_ATTR2_ARRAYBASE
        attributes['is_array'] = pybool(is_array)
        if is_array:
            attributes['n_elements'] = attr.iProp_NumberOfElement

        # min/max/step
        if attr.attribute & DCAMPROPATTRIBUTE.DCAMPROP_ATTR_HASRANGE:
            attributes.update({'min': attr.valuemin, 'max': attr.valuemax})
        if attr.attribute & DCAMPROPATTRIBUTE.DCAMPROP_ATTR_HASSTEP:
            attributes['step'] = attr.valuestep
        if attr.attribute & DCAMPROPATTRIBUTE.DCAMPROP_ATTR_HASDEFAULT:
            attributes['default'] = attr.valuedefault

        # update details
        cdef double value
        if attributes['type'] == 'mode':
            value = attributes['min']
            mode_text = []
            while True:
                text = self._get_value_text(iprop, value)
                text = text.lower().replace(" ", "_")
                mode_text.append(text)
                try:
                    value = self._query_value(iprop, value)
                except RuntimeError:
                    # last value reached
                    break
            attributes['modes'] = tuple(mode_text)

        return attributes

    cpdef get_value(self, int32 iprop):
        cdef double value

        cdef DCAMERR err
        err = dcamprop_getvalue(self.handle, iprop, &value)
        DCAMAPI.check_error(err, 'dcamprop_getvalue()', self.handle)

        return value

    cpdef set_value(self, int32 iprop, double value):
        cdef DCAMERR err
        err = dcamprop_setvalue(self.handle, iprop, value)
        DCAMAPI.check_error(err, 'dcamprop_setvalue()', self.handle)

    def set_get_value(self, int32 iprop, double value):
        cdef DCAMERR err
        err = dcamprop_setgetvalue(self.handle, iprop, &value)
        DCAMAPI.check_error(err, 'dcamprop_setgetvalue()', self.handle)

        return value

    cdef _query_value(self, int32 iprop, double value):
        cdef DCAMERR err
        err = dcamprop_queryvalue(self.handle, iprop, &value, DCAMPROPOPTION.DCAMPROP_OPTION_NEXT)
        DCAMAPI.check_error(err, 'dcamprop_queryvalue()', self.handle)

        return value

    cpdef get_next_id(self, int32 iprop=0):
        cdef DCAMERR err
        err = dcamprop_getnextid(self.handle, &iprop, DCAMPROPOPTION.DCAMPROP_OPTION_SUPPORT)
        DCAMAPI.check_error(err, 'dcamprop_getnextid()', self.handle)

        return iprop

    cpdef get_name(self, int32 iprop, int32 nbytes=64):
        cdef char[::1] text = view.array(shape=(nbytes, ), itemsize=sizeof(char), format='c')
        cdef char *c_text = &text[0]

        cdef DCAMERR err
        err = dcamprop_getname(self.handle, iprop, c_text, nbytes)
        DCAMAPI.check_error(err, 'dcamprop_getname()', self.handle)

        return c_text.decode('utf-8', errors='replace')

    cdef _get_value_text(self, int32 iprop, double valuemin, int32 nbytes=64):
        cdef char[::1] text = view.array(shape=(nbytes, ), itemsize=sizeof(char), format='c')
        cdef char *c_text = &text[0]

        cdef DCAMPROP_VALUETEXT value
        memset(&value, 0, sizeof(value))
        value.cbSize = sizeof(value)
        value.iProp	= iprop
        value.value	= valuemin
        value.text = c_text
        value.textbytes = nbytes

        cdef DCAMERR err
        err = dcamprop_getvaluetext(self.handle, &value)
        DCAMAPI.check_error(err, 'dcamprop_getvaluetext()', self.handle)

        return c_text.decode('utf-8', errors='replace')
    ##
    ## property control
    ##

    ##
    ## buffer control
    ##
    cpdef alloc(self, int32 nframes):
        """
        Allocates internal image buffers for image acquisition.
        """
        cdef DCAMERR err
        err = dcambuf_alloc(self.handle, nframes)
        DCAMAPI.check_error(err, 'dcambuf_alloc()', self.handle)

    cpdef attach(self, list buffer):
        """
        Attach external image buffers for image acquisition.
        """
        cdef int nframes = <int>len(buffer)
        if nframes < 1:
            raise RuntimeError('number of frames has to be >= 1')

        # build pointer array
        self.buffer = np.empty(nframes, dtype=np.uintp)
        cdef uint8_t[::1] frame
        for i in range(nframes):
            frame = buffer[i]#.get_obj()
            self.buffer[i] = <uintptr_t>&frame[0]

        cdef DCAMBUF_ATTACH bufattach
        memset(&bufattach, 0, sizeof(bufattach))
        bufattach.size = sizeof(bufattach)
        bufattach.iKind = DCAMBUF_ATTACHKIND.DCAMBUF_ATTACHKIND_FRAME
        bufattach.buffer = <void **>&self.buffer[0]
        bufattach.buffercount = nframes

        cdef DCAMERR err
        err = dcambuf_attach(self.handle, &bufattach)
        DCAMAPI.check_error(err, 'dcambuf_attach()', self.handle)

    def release(self):
        """
        Releases capturing buffer allocated by dcambuf_alloc() or assigned by dcambuf_attached().
        """
        cdef DCAMERR err
        err = dcambuf_release(self.handle)
        DCAMAPI.check_error(err, 'dcambuf_release()', self.handle)

        self.buffer = None

    cpdef lock_frame(self, int32 iframe=-1):
        """
        Returns a pointer that the host software can use to access the captured image data.

        Args:
            iframe (int): frame index, -1 to retrieve the latest frame
        """
        cdef DCAMBUF_FRAME bufframe
        memset(&bufframe, 0, sizeof(bufframe))
        bufframe.size = sizeof(bufframe)
        bufframe.iFrame = iframe

        cdef DCAMERR err
        err = dcambuf_lockframe(self.handle, &bufframe)
        DCAMAPI.check_error(err, 'dcambuf_lockframe()', self.handle)

        # bufframe.buf, bufframe.rowbytes, bufframe.type, bufframe.width, bufframe.height
        if bufframe.type == DCAM_PIXELTYPE.DCAM_PIXELTYPE_MONO16:
            return np.asarray(<np.uint16_t[:bufframe.height, :bufframe.width]>bufframe.buf)
        else:
            raise NotImplementedError(f'unsupported pixel format')

    def copy_frame(self):
        pass

    def copy_metadata(self):
        pass
    ##
    ## buffer control
    ##

    ##
    ## capturing
    ##
    cpdef start(self, int32 mode):
        """
        Start capturing images.
        """
        cdef DCAMERR err
        err = dcamcap_start(self.handle, mode)
        DCAMAPI.check_error(err, 'dcamcap_start()', self.handle)

    def stop(self):
        """
        Terminates the acquisition.
        """
        cdef DCAMERR err
        err = dcamcap_stop(self.handle)
        DCAMAPI.check_error(err, 'dcamcap_stop()', self.handle)

    def status(self) -> CaptureStatus:
        """
        Returns current capturing status.
        """
        cdef int32 status

        cdef DCAMERR err
        err = dcamcap_status(self.handle, &status)
        DCAMAPI.check_error(err, 'dcamcap_status()', self.handle)

        return CaptureStatus(status)

    def transfer_info(self):
        cdef DCAMCAP_TRANSFERINFO info
        memset(&info, 0, sizeof(info))
        info.size = sizeof(info)

        cdef DCAMERR err
        err = dcamcap_transferinfo(self.handle, &info)
        DCAMAPI.check_error(err, 'dcamcap_transferinfo()', self.handle)

        return info.nNewestFrameIndex, info.nFrameCount

    def fire_trigger(self):
        cdef DCAMERR err
        err = dcamcap_firetrigger(self.handle)
        DCAMAPI.check_error(err, 'dcamcap_firetrigger()', self.handle)
    ##
    ## capturing
    ##

    @property
    def event(self):
        return DCAMWAIT(<uintptr_t>self.handle)