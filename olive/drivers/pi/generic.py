from functools import lru_cache
import logging
from multiprocessing.sharedctypes import RawArray
import re

import numpy as np

from olive.core import DeviceInfo, Driver
from olive.devices import LinearAxis, MotionController
from olive.devices.errors import UnsupportedDeviceError

from .wrapper import Command, Communication

__all__ = ["GCS2"]

logger = logging.getLogger(__name__)


class PIAxis(object):
    def __init__(self, axis_id):
        self._axis_id = axis_id

    ##

    @property
    def axis_id(self):
        return self._axis_id

    @property
    @lru_cache(maxsize=1)
    def info(self):
        # extract info from parent
        parent_info = self.parent.info

        parms = {
            "vendor": parent_info.vendor,
            "model": self.handle.get_stage_type(self.axis_id),
            "version": parent_info.version,
            "serial_number": parent_info.sn,
        }
        return DeviceInfo(**parms)


class PILinear(PIAxis, LinearAxis):
    def __init__(self, parent, axis_id):
        LinearAxis.__init__(self, parent.driver, parent=parent)
        PIAxis.__init__(self, axis_id)
        self._handle, self._axis_id = parent.handle, axis_id

    ##

    def enumerate_properties(self):
        # TODO use reponse from qSPA
        pass

    ##

    @property
    def handle(self):
        return self._handle


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
        return ("help", "parameters", "versions")

    ##

    def _get_help(self):
        response = PIController._retrieve_large_response(self.handle.get_help)

        result = dict()
        for line in response.split("\n"):
            key, value = tuple(line.split(" ", maxsplit=1))
            result[key.strip()] = value.strip()

        # TODO isolate syntax / help string

        return result

    def _get_parameters(self):
        response = PIController._retrieve_large_response(self.handle.get_parameters)

        # response format
        #   <PamID>=
        #       <CmdLevel>\t
        #       <MaxItem>\t
        #       <DataType>\t
        #       <FuncDesc>\t
        #       <Desc>
        #       [{\t<Value>=<Desc>}]
        pids = []
        for line in response.split("\n"):
            if not line.startswith("0x"):
                continue
            pid, desc = line.split("=", maxsplit=1)
            pid, desc = int(pid, 16), desc.strip()

            cmd_level, max_item, dtype, _, desc, *options = desc.split("\t")
            pids.append((pid, desc))
        return tuple(pids)

    def _get_versions(self):
        response = PIController._retrieve_large_response(self.handle.get_version)

        # split version strings
        result = dict()
        for line in response.split("\n"):
            key, value = tuple(line.split(":", maxsplit=1))
            result[key.strip()] = value.strip()

        return result

    ##

    def enumerate_axes(self):
        axes = []
        for axis_id in self.handle.get_axes_id().split("\n"):
            print(axis_id)

    ##

    @property
    def busy(self):
        return self.handle.is_running_macro or not self.handle.is_controller_ready()

    @property
    def handle(self):
        return self._handle

    @property
    def idn(self):
        return self._idn

    @property
    @lru_cache(maxsize=1)
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

    @staticmethod
    def _retrieve_large_response(func, start_size=1024, max_size=2 ** 20, strip=True):
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

    @lru_cache(maxsize=1)
    def _valid_character_set(self):
        """
        Query valid character set for axis identifier.
        """
        return self.handle.get_valid_character_set()


class PIDaisyController(PIController):
    def __init__(self, driver, daisy_index, parent=None, timeout=1000):
        super().__init__(driver, idn, timeout=1000)
        self._daisy_index = daisy_index

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
        ctrl_id = self.driver.api.connect_daisy_chain_device(
            self.parrent.daisy_index, self.daisy_index
        )
        self._handle = Command(ctrl_id)

        self.handle.set_error_check(True)

    def close(self):
        ctrl_id = self.handle.ctrl_id
        self.driver.api.close_connection(ctrl_id)
        self._handle = None

    ##

    @property
    def daisy_index(self):
        return self._daisy_index


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

        # construct controller objects
        candidates = [PIController(self, idn) for idn in dev_idn]

        valid_devices = []
        while candidates:
            device = candidates.pop()
            try:
                # standard test
                device.test_open()

                # are there any slave?
                try:
                    daisy_id, n_dev, dev_idn = self.api.open_usb_daisy_chain(device.idn)
                    if n_dev == 1:
                        raise StopIteration
                    # expand the result
                    logger.debug(f"found {n_dev} slave(s)")
                except RuntimeError:
                    # unknown runtime error
                    pass
                except StopIteration:
                    # single device
                    valid_devices.append(device)
                finally:
                    self.api.close_daisy_chain(daisy_id)
            except UnsupportedDeviceError:
                pass

        return tuple(valid_devices)

    ##

    @property
    def api(self):
        return self._api
