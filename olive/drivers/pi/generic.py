import logging
from multiprocessing.sharedctypes import RawArray
import re

import numpy as np

from olive.core import Driver, DeviceInfo
from olive.devices import MotionController
from olive.devices.errors import UnsupportedDeviceError

from .wrapper import Communication

__all__ = ["GCS2"]

logger = logging.getLogger(__name__)


class PIController(MotionController):
    def __init__(self, driver, idn, timeout=1000):
        super().__init__(driver, timeout)
        self._idn, self._ctrl_id = idn, -1

    def test_open(self):
        pass

    def open(self):
        pass

    def close(self):
        pass

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

    ##

    @property
    def ctrl_id(self):
        return self._ctrl_id

    @property
    def idn(self):
        return self._idn


class GCS2(Driver):
    def __init__(self):
        self._api = Communication()

    ##

    def initialize(self, error_check=True):
        pass

    def shutdown(self):
        pass

    def enumerate_devices(self, keyword: str = "") -> PIController:
        response = self.api.enumerate_usb(keyword)
        dev_idn = list(response.strip().split("\n"))

        valid_devices = []
        for idn in dev_idn:
            try:
                device = PIController(self, idn)
            except UnsupportedDeviceError:
                pass

        return tuple(valid_devices)

    ##

    @property
    def api(self):
        return self._api
