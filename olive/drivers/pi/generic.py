import logging
from multiprocessing.sharedctypes import RawArray
import re

import numpy as np

from olive.core import Driver, DeviceInfo
from olive.devices import MotionController
from olive.devices.errors import UnsupportedDeviceError

from .wrapper import GCS2 as _GCS2

__all__ = ["GCS2"]

logger = logging.getLogger(__name__)


class PIController(MotionController):
    def __init__(self, driver, timeout=1000):
        super().__init__(driver, timeout)

    ##

    def enumerate_properties(self):
        pass

    ##

    def enumerate_axes(self):
        pass

    ##

    def busy(self):
        return False

    def info(self):
        pass


class PIUSBController(PIController):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    ##

    def test_open(self):
        pass

    def open(self):
        pass

    def close(self):
        pass


class GCS2(Driver):
    def __init__(self):
        self._api = _GCS2()

    ##

    def initialize(self, error_check=True):
        pass

    def shutdown(self):
        pass

    def enumerate_devices(self, keyword: str = None):
        response = self.api.enumerate_usb(keyword)
        dev_idn = list(response.split('\n'))

        return result

    ##

    @property
    def api(self):
        return self._api
