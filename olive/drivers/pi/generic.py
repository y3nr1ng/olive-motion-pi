import logging
from multiprocessing.sharedctypes import RawArray
import re

import numpy as np

from olive.core import Driver, DeviceInfo
from olive.devices import MotionController
from olive.devices.errors import UnsupportedDeviceError

from .wrapper import Command, Communication

__all__ = ["GCS2"]

logger = logging.getLogger(__name__)


class PIController(MotionController):
    def __init__(self, driver, idn, timeout=1000):
        super().__init__(driver, timeout)
        self._idn, self._handle = idn, None

    ##

    def test_open(self):
        api = self.driver.api
        try:
            ctrl_id = api.connect_usb(self.idn)
            self._handle = Command(ctrl_id)
            logger.info(f"..{self.info}")
        except RuntimeError as err:
            logger.exception(err)
            raise UnsupportedDeviceError
        finally:
            api.close_connection(ctrl_id)

    def open(self):
        ctrl_id = self.driver.api.connect_usb(self.idn)
        self._handle = Command(ctrl_id)

        self.handle.set_error_check(True)

    def close(self):
        ctrl_id = self.handle.ctrl_id
        self.driver.api.close_connection(ctrl_id)
        self._handle = None

    ##

    def enumerate_properties(self):
        return ("help", "versions")

    ##

    def enumerate_axes(self):
        pass

    ##

    @property
    def busy(self):
        return False

    @property
    def handle(self):
        return self._handle

    @property
    def idn(self):
        return self._idn

    @property
    def info(self):
        # extract info from *IDN?, since SSN? may not exist
        vendor, model, *args = self.idn.split(" ")
        sn = args[-1]

        # extract version
        versions = self._get_versions()
        # .. find GCS2 DLL
        version = None
        for key, value in versions.items():
            if "PI_GCS2" in key:
                version = value
                break
        else:
            logger.warning("unable to determine GCS2 version")
            version = "UNKNOWN"

        return DeviceInfo(vendor=vendor, model=model, version=version, serial_number=sn)

    ##

    def _get_help(self, max_bytes=2 ** 20):
        response = PIController._retrieve_large_response(self.handle.get_help)

        result = dict()
        for line in response.split('\n'):
            key, value = tuple(line.split(' ', maxsplit=1))
            result[key.strip()] = value.strip()

        # TODO isolate syntax / help string

        return result

    def _get_versions(self):
        response = PIController._retrieve_large_response(self.handle.get_version)

        # split version strings
        result = dict()
        for line in response.split("\n"):
            key, value = tuple(line.split(":", maxsplit=1))
            result[key.strip()] = value.strip()

        return result

    ##

    @staticmethod
    def _retrieve_large_response(func, start_size=128, max_size=2 ** 20, strip=True):
        response, nbytes = None, start_size
        while nbytes < max_size:
            try:
                response = func(nbytes)
                if strip:
                    response = response.strip()
                break
            except RuntimeError as err:
                if "overflow" in str(err):
                    nbytes *= 2
                    logger.warning(f"overflow, increase buffer to {nbytes} bytes")
                else:
                    raise
        return response


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
                device.test_open()
                valid_devices.append(device)
            except UnsupportedDeviceError:
                pass

        return tuple(valid_devices)

    ##

    @property
    def api(self):
        return self._api
