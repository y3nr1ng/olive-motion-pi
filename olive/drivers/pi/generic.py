from functools import lru_cache
import logging
from multiprocessing.sharedctypes import RawArray
import re
from typing import Union

import numpy as np

from olive.core import Device, DeviceInfo, Driver
from olive.devices import LinearAxis, MotionController, RotaryAxis
from olive.devices.errors import UnsupportedDeviceError
from olive.devices.motion import Axis

from .wrapper import Command, Communication

__all__ = ["GCS2"]

logger = logging.getLogger(__name__)


class PIAxis(Axis):
    def __init__(self, parent, axis_id, *args, **kwargs):
        super().__init__(parent.driver, *args, parent=parent, **kwargs)
        self._handle, self._axis_id = parent.handle, axis_id

    ##

    def enumerate_properties(self):
        return list(self.parent.get_property("available_parameters").keys())

    def get_property(self, name):
        pid, dtype, max_item = self.parent.get_property("available_parameters")[name]
        value_num, value_str = self.handle.get_axes_parameter(self.axis_id, [pid])
        if dtype == "char":
            return value_str
        else:
            # extract limited portion to prevent memory access violation
            value_num = value_num[:max_item]

            # convert integers if require
            if dtype == "int":
                value_num = [int(v) for v in value_num]

            # simplify
            return value_num[0] if max_item == 1 else value_num

    def set_property(self, name, value):
        raise NotImplementedError

    ##

    @property
    def axis_id(self):
        return self._axis_id

    @property
    def handle(self):
        return self._handle

    @property
    @lru_cache(maxsize=1)
    def info(self):
        model = self.handle.get_stage_type(self.axis_id).strip()
        model = model.split("=")[1]

        # extract info from parent
        parent_info = self.parent.info
        parms = {
            "vendor": parent_info.vendor,
            "model": model,
            "version": parent_info.version,
            "serial_number": parent_info.serial_number,
        }
        return DeviceInfo(**parms)


class PILinear(PIAxis, LinearAxis):
    def __init__(self, parent, axis_id):
        super().__init__(parent=parent, axis_id=axis_id)

    def test_open(self):
        self.open()
        try:
            if self.get_property("is_rotary_stage") > 0:
                raise UnsupportedDeviceError
            logger.info(f".. {self.info}")
        except RuntimeError as err:
            logger.exception(err)
            raise UnsupportedDeviceError
        finally:
            self.close()

    ##


class PIRotary(PIAxis, RotaryAxis):
    def __init__(self, parent, axis_id):
        super().__init__(axis_id=axis_id, parent=parent)

    def test_open(self):
        self.open()
        try:
            if self.get_property("is_rotary_stage") == 0:
                raise UnsupportedDeviceError
            logger.info(f".. {self.info}")
        except RuntimeError as err:
            logger.exception(err)
            raise UnsupportedDeviceError
        finally:
            self.close()


class PIController(MotionController):
    def __init__(self, driver, desc_str, *args, **kwargs):
        super().__init__(driver, *args, **kwargs)
        self._desc_str, self._handle = desc_str, None

    ##

    def test_open(self):
        api = self.driver.api
        ctrl_id = -1
        try:
            ctrl_id = api.connect_usb(self.desc_str)
            self._handle = Command(ctrl_id)
            logger.info(f".. {self.info}")
        except RuntimeError as err:
            logger.exception(err)
            raise UnsupportedDeviceError
        finally:
            api.close_connection(ctrl_id)
            self._handle = None

    def _open(self):
        ctrl_id = self.driver.api.connect_usb(self.desc_str)
        self._handle = Command(ctrl_id)

    def _close(self):
        self.driver.api.close_connection(self.handle.ctrl_id)
        self._handle = None

    ##

    def enumerate_properties(self):
        return ("available_commands", "available_parameters", "versions")

    ##

    def _get_available_commands(self):
        response = PIController._retrieve_large_response(
            self.handle.get_available_commands
        )

        result = dict()
        for line in response.split("\n"):
            key, value = tuple(line.split(" ", maxsplit=1))
            result[key.strip()] = value.strip()

        # TODO isolate syntax / help string

        return result

    @lru_cache(maxsize=1)
    def _get_available_parameters(self):
        response = PIController._retrieve_large_response(
            self.handle.get_available_parameters
        )

        # response format
        #   <PamID>=
        #       <CmdLevel>\t
        #       <MaxItem>\t
        #       <DataType>\t
        #       <FuncDesc>\t
        #       <Desc>
        #       [{\t<Value>=<Desc>}]
        pids = dict()
        for line in response.split("\n"):
            if not line.startswith("0x"):
                continue
            pid, desc = line.split("=", maxsplit=1)
            pid, desc = int(pid, 16), desc.strip()

            cmd_level, max_item, dtype, _, desc, *options = desc.split("\t")

            # normalize the name
            #   'Device S/N'
            #       -> 'device_sn'
            #   'Closed-Loop Deceleration For HI Control (Phys. Unit/s2)'
            #       -> 'closed_loop_deceleration_for_hi_control'
            #   'Is Rotary Stage?'
            #       -> 'is_rotary_stage'
            desc = desc.lower()
            desc = desc.split("(")[0].strip()
            desc = re.sub(r"[\-\s]+", "_", desc)
            desc = re.sub(r"[^0-9a-zA-Z_]+", "", desc)

            # normalize paramter info
            dtype, max_item = dtype.lower(), int(max_item)

            pids[desc] = (pid, dtype, max_item)
        return pids

    def _get_versions(self):
        """
        Note:
            This is F*CKING slow on Windows 7.
        """
        response = PIController._retrieve_large_response(self.handle.get_version)

        # split version strings
        result = dict()
        for line in response.split("\n"):
            key, value = tuple(line.split(":", maxsplit=1))
            result[key.strip()] = value.strip()

        return result

    ##

    def enumerate_axes(self) -> Union[PILinear, PIRotary]:
        ax_klass, ax_id = (
            set(PIAxis.__subclasses__()),
            self.handle.get_axes_id().strip().split("\n"),
        )

        axes = []
        for axis_id in ax_id:
            for klass in ax_klass:
                axis = klass(self, axis_id)
                try:
                    axis.test_open()
                    axes.append(axis)
                    break
                except UnsupportedDeviceError:
                    pass
            else:
                logger.error(f"unknown axes {axis_id}")
        return tuple(axes)

    ##

    @property
    def busy(self):
        return self.handle.is_running_macro or not self.handle.is_controller_ready()

    @property
    def handle(self):
        return self._handle

    @property
    def desc_str(self):
        return self._desc_str

    @property
    @lru_cache(maxsize=1)
    def info(self):
        response = self.handle.get_identification_string()
        vendor, model, sn, version = tuple(
            token.strip() for token in response.split(",")
        )
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
    def __init__(self, driver, desc_str):
        super().__init__(driver)
        self._desc_str = desc_str
        self._daisy_id = -1

    ##

    def test_open(self):
        api = self.driver.api
        daisy_id = -1
        try:
            daisy_id, n_dev, _ = api.open_usb_daisy_chain(self.desc_str)
            if n_dev == 1:
                # shunt to error
                raise UnsupportedDeviceError
            logger.info(f".. {self.info}")
        except RuntimeError as err:
            logger.exception(err)
            raise UnsupportedDeviceError
        finally:
            api.close_daisy_chain(daisy_id)

    def _open(self):
        print(">>> OPEN DAISY")
        self._daisy_id, self._n_members, _ = self.driver.api.open_usb_daisy_chain(
            self.desc_str
        )

    def _close(self):
        print("<<< CLOSE DAISY")
        self.driver.api.close_daisy_chain(self.daisy_id)
        self._daisy_id = -1

    ##

    def enumerate_properties(self):
        return ("number_of_members",)

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
    def desc_str(self):
        return self._desc_str

    @property
    @lru_cache(maxsize=1)
    def info(self):
        # extract info from *IDN?, since SSN? may not exist
        vendor, *args = self.desc_str.split(" ")
        sn = args[-1]

        return DeviceInfo(vendor=vendor, model="DAISY", version=None, serial_number=sn)

    @property
    def is_opened(self):
        return self.daisy_id >= 0


class PIDaisyController(PIController, MotionController):
    def __init__(self, parent: PIDaisyChain, daisy_index):
        super().__init__(driver=parent.driver, desc_str=None, parent=parent)
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

    def _open(self):
        ctrl_id = self.driver.api.connect_daisy_chain_device(
            self.parent.daisy_id, self.daisy_index
        )
        self._handle = Command(ctrl_id)

    ##

    @property
    def daisy_index(self):
        return self._daisy_index


class GCS2(Driver):
    def __init__(self):
        self._api = Communication()

    ##

    def initialize(self, error_check=True):
        self.api.set_daisy_chain_scan_max_device_id(4)

    def shutdown(self):
        pass

    def enumerate_devices(self, keyword: str = "") -> PIController:
        response = self.api.enumerate_usb(keyword)
        desc_strs = list(response.strip().split("\n"))
        logger.debug(f"found {len(desc_strs)} controller candidate(s)")

        valid_controllers = []
        for desc_str in desc_strs:
            logger.debug(f"desc_str: {desc_str}")
            chain = PIDaisyChain(self, desc_str)
            try:
                chain.test_open()

                # a daisy-chain master
                chain.open()
                # iterate over member index
                n_members = chain.get_property("number_of_members")
                logger.info(f"found {n_members} member(s)")
                for index in range(1, n_members + 1):
                    try:
                        logger.debug(f".. index: {index}")
                        device = PIDaisyController(chain, index)
                        device.test_open()
                        valid_controllers.append(device)
                    except UnsupportedDeviceError:
                        pass
                chain.close()
            except UnsupportedDeviceError:
                # rebuild an independent controller
                device = PIController(self, desc_str)
                try:
                    device.test_open()
                    valid_controllers.append(device)
                except UnsupportedDeviceError:
                    pass

        valid_axes = []
        for controller in valid_controllers:
            controller.open()
            try:
                valid_axes.extend(controller.enumerate_axes())
            finally:
                controller.close()
        return tuple(valid_axes)

    ##

    @property
    def api(self):
        return self._api
