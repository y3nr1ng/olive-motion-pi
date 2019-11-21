from functools import lru_cache
import logging
from multiprocessing.sharedctypes import RawArray
import re

import numpy as np

from olive.core import Device, DeviceInfo, Driver
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
    def __init__(self, driver, idn, *args, **kwargs):
        super().__init__(driver, *args, **kwargs)
        self._idn, self._handle = idn, None

    ##

    def test_open(self):
        try:
            self.open()
            logger.info(f".. {self.info}")
        except RuntimeError as err:
            logger.exception(err)
            raise UnsupportedDeviceError
        finally:
            self.close()

    def open(self):
        ctrl_id = self.driver.api.connect_usb(self.idn)
        self._handle = Command(ctrl_id)

    def close(self):
        self.driver.api.close_connection(self.handle.ctrl_id)
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
        try:
            # extract info from enumerated description
            vendor, model, *args = self.idn.split(" ")
            sn = args[-1]
        except AttributeError:
            # daisy chained device requires qIDN
            response = self.handle.get_identification_string()
            response = tuple(token.strip() for token in response.split(","))
            vendor, model, sn, *args = response

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

    @property
    def is_opened(self):
        return self.handle is not None

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


class PIDaisyChain(Device):
    def __init__(self, driver, idn):
        super().__init__(driver)
        self._idn = idn

        self._daisy_id = -1
        self._n_members, self._active_members = 0, []

    ##

    def test_open(self):
        api = self.driver.api
        try:
            daisy_id, n_dev, _ = api.open_usb_daisy_chain(self.idn)
            if n_dev == 1:
                # shunt to error
                raise UnsupportedDeviceError
            logger.info(f".. {self.info}")
        except RuntimeError as err:
            logger.exception(err)
            raise UnsupportedDeviceError
        finally:
            api.close_daisy_chain(daisy_id)

    def open(self):
        if self.is_opened:
            return

        # open the chain
        self._daisy_id, self._n_members, _ = self.driver.api.open_usb_daisy_chain(
            self.idn
        )
        # reset active list
        self._active_members = dict()

    def register(self, member: "PIDaisyController"):
        logger.debug(
            f"<REGIS> daisy id: {self.daisy_id}, daisy_index: {member.daisy_index}"
        )
        self._active_members[member.daisy_index] = member

    def unregister(self, member: "PIDaisyController"):
        self._active_members.pop(member.daisy_index)
        logger.debug(
            f"<UNREG> daisy id: {self.daisy_id}, daisy_index: {member.daisy_index}"
        )

    def close(self):
        if self._active_members:
            logger.warning("there are still active members, unable to close")
            return

        self.driver.api.close_daisy_chain(self.daisy_id)
        self._daisy_id = -1

    ##

    def enumerate_properties(self):
        return ("active_members", "number_of_members")

    def _get_active_members(self):
        return self._active_members

    def _get_number_of_members(self):
        return self._n_members

    ##

    @property
    def busy(self):
        return False

    @property
    def daisy_id(self):
        return self._daisy_id

    @property
    def idn(self):
        return self._idn

    @property
    @lru_cache(maxsize=1)
    def info(self):
        # extract info from *IDN?, since SSN? may not exist
        vendor, *args = self.idn.split(" ")
        sn = args[-1]

        return DeviceInfo(vendor=vendor, model="DAISY", version=None, serial_number=sn)

    @property
    def is_opened(self):
        return self.daisy_id >= 0


class PIDaisyController(PIController, MotionController):
    def __init__(self, parent: PIDaisyChain, daisy_index):
        super().__init__(driver=parent.driver, idn=None, parent=parent)
        self._daisy_index = daisy_index

    ##

    def test_open(self):
        try:
            # use daisy ID from the parent
            self.open()
            logger.info(f".. {self.info}")
        except RuntimeError as err:
            logger.exception(err)
            raise UnsupportedDeviceError
        finally:
            self.close()

    def open(self):
        # open daisy chain
        self.parent.open()
        # open daisy member
        ctrl_id = self.driver.api.connect_daisy_chain_device(
            self.parent.daisy_id, self.daisy_index
        )
        self._handle = Command(ctrl_id)
        # register
        self.parent.register(self)

    def close(self):
        # close daisy member
        super().close()
        # unregister
        self.parent.unregister(self)
        # close daisy chain
        self.parent.close()

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

        valid_devices = []
        for idn in dev_idn:
            chain = PIDaisyChain(self, idn)
            try:
                chain.test_open()

                # a daisy-chain master
                chain.open()
                # iterate over member index
                n_members = chain.get_property("number_of_members")
                logger.info(f"found {n_members} member(s)")
                for index in range(1, n_members + 1):
                    try:
                        device = PIDaisyController(chain, index)
                        device.test_open()
                        valid_devices.append(device)
                    except UnsupportedDeviceError:
                        pass
                chain.close()
            except UnsupportedDeviceError:
                # rebuild an independent controller
                device = PIController(self, idn)
                try:
                    device.test_open()
                    valid_devices.append(device)
                except UnsupportedDeviceError:
                    pass

        return tuple(valid_devices)

    ##

    @property
    def api(self):
        return self._api
