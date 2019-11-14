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
        api, ctrl_id = self.driver.api, -1
        try:
            thread_id = api.try_connect_usb(self.idn)

            import time
            while api.is_connecting(thread_id):
                logger.debug('.. connecting')
                time.sleep(0.1)
            logger.debug('connected!')

            ctrl_id = api.get_controller_id(thread_id)
            logger.debug(f'thread {thread_id} -> ctrl {ctrl_id}')
            self._handle = Command(ctrl_id)
            logger.info(f"..{self.info}")
        except RuntimeError as err:
            logger.exception(err)
            raise UnsupportedDeviceError
        finally:
            api.close_connection(ctrl_id)
            self._handle = None

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
        print('===')
        print(self.handle.get_help())
        print()

        params = {
            "version": 'N/A',
            "vendor": 'PI',
            "model": 'N/A',
            "serial_number": 'N/A',
        }

        return DeviceInfo(**params)


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
