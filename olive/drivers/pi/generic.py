from functools import lru_cache
import logging
from multiprocessing.sharedctypes import RawArray
import re
import trio
from typing import Union

import numpy as np

from olive.core import Device, DeviceInfo, Driver
from olive.devices import LinearAxis, MotionController, RotaryAxis
from olive.devices.errors import UnsupportedDeviceError
from olive.devices.motion import Axis

from .wrapper import (
    AxisCommand,
    ControllerCommand,
    Communication,
    ReferenceMode,
    ReferenceStrategy,
    ServoState,
)

__all__ = ["GCS2"]

logger = logging.getLogger(__name__)


class PIAxis(Axis):
    def __init__(self, parent, axis_id, *args, **kwargs):
        super().__init__(parent.driver, *args, parent=parent, **kwargs)
        self._handle = AxisCommand(parent.handle.ctrl_id, axis_id)

    async def _open(self):
        # must use closed-loop
        self.handle.set_servo_state(ServoState.ClosedLoop)

        # referenced mode
        self.handle.set_reference_mode(ReferenceMode.Absolute)
        if not self.handle.is_referenced():
            # TODO lock to center for now
            self.handle.start_reference(ReferenceStrategy.ReferencePoint)
        await self.wait()

    ##

    async def enumerate_properties(self):
        return tuple((await self.parent.get_property("available_parameters")).keys())

    async def get_property(self, name):
        prop_detail = (await self.parent.get_property("available_parameters"))[name]
        pid, dtype, max_item = prop_detail
        value_num, value_str = self.handle.get_parameter([pid])
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

    async def set_property(self, name, value):
        raise NotImplementedError

    ##

    async def home(self):
        await trio.to_thread.run_sync(self.handle.go_to_home)
        await self.wait()

    async def get_position(self):
        return self.handle.get_current_position()

    async def set_absolute_position(self, pos):
        self.handle.set_target_position(pos)

    async def set_relative_position(self, pos):
        self.handle.set_relative_target_position(pos)
        await self.wait()

    ##

    async def get_velocity(self):
        return self.handle.get_velocity()

    async def set_velocity(self, vel):
        self.handle.set_velocity(vel)

    ##

    async def get_acceleration(self):
        return self.handle.get_acceleration()

    async def set_acceleration(self, acc):
        self.handle.set_acceleration(acc)

    ##

    async def set_origin(self):
        """Define current position as the origin."""

    async def get_limits(self):
        """
        TMN low end of the travel range
        TMX high end of the travel range

        NLM set lower limits (soft limit)
        PLM set higher limits (soft limit)
        """
        pass

    async def set_limits(self):
        pass

    ##

    async def stop(self, emergency=False):
        if emergency:
            self.handle.stop_all()
        else:
            self.handle.halt()

    async def wait(self):
        while self.busy:
            await trio.sleep(1)

    ##

    @property
    def busy(self):
        return self.parent.busy or self.handle.is_moving()

    @property
    def handle(self):
        return self._handle

    @property
    @lru_cache(maxsize=1)
    def info(self):
        model = self.handle.get_stage_type().strip()
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

    ##

    async def test_open(self):
        try:
            await self.open()
            if (await self.get_property("is_rotary_stage")) > 0:
                raise UnsupportedDeviceError
            logger.info(f".. {self.info}")
        except RuntimeError as err:
            logger.exception(err)
            raise UnsupportedDeviceError
        finally:
            await self.close()

    ##


class PIRotary(PIAxis, RotaryAxis):
    def __init__(self, parent, axis_id):
        super().__init__(axis_id=axis_id, parent=parent)

    ##

    async def test_open(self):
        try:
            await self.open()
            if (await self.get_property("is_rotary_stage")) == 0:
                raise UnsupportedDeviceError
            logger.info(f".. {self.info}")
        except RuntimeError as err:
            logger.exception(err)
            raise UnsupportedDeviceError
        finally:
            await self.close()


class PIController(MotionController):
    def __init__(self, driver, desc_str, *args, **kwargs):
        super().__init__(driver, *args, **kwargs)
        self._desc_str, self._handle = desc_str, None

    ##

    async def test_open(self):
        try:
            await self.open()
            logger.info(f".. {self.info}")
        except RuntimeError as err:
            logger.exception(err)
            raise UnsupportedDeviceError
        finally:
            await self.close()

    async def _open(self):
        ctrl_id = await trio.to_thread.run_sync(
            self.driver.api.connect_usb, self.desc_str
        )
        self._handle = ControllerCommand(ctrl_id)

    async def _close(self):
        await trio.to_thread.run_sync(
            self.driver.api.close_connection, self.handle.ctrl_id
        )
        self._handle = None

    ##

    async def enumerate_properties(self):
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

    async def enumerate_axes(self) -> Union[PILinear, PIRotary]:
        ax_klass, ax_id = (
            set(PIAxis.__subclasses__()),
            self.handle.get_axes_id().strip().split("\n"),
        )

        axes = []
        for axis_id in ax_id:
            for klass in ax_klass:
                axis = klass(self, axis_id)
                try:
                    await axis.test_open()
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
        return self.handle.is_running_macro() or not self.handle.is_controller_ready()

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

    async def test_open(self):
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

    async def _open(self):
        self._daisy_id, self._n_members, _ = await trio.to_thread.run_sync(
            self.driver.api.open_usb_daisy_chain, self.desc_str
        )

    async def _close(self):
        await trio.to_thread.run_sync(self.driver.api.close_daisy_chain, self.daisy_id)
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

    async def test_open(self):
        try:
            # use daisy ID from the parent
            await self.open()
            logger.info(f".. {self.info}")
        except RuntimeError as err:
            logger.exception(err)
            raise UnsupportedDeviceError
        finally:
            await self.close()

    async def _open(self):
        ctrl_id = await trio.to_thread.run_sync(
            self.driver.api.connect_daisy_chain_device,
            self.parent.daisy_id,
            self.daisy_index,
        )
        self._handle = ControllerCommand(ctrl_id)

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

    async def enumerate_devices(self, keyword: str = "") -> PIController:
        response = self.api.enumerate_usb(keyword)
        desc_strs = list(response.strip().split("\n"))
        logger.debug(f"found {len(desc_strs)} controller candidate(s)")

        valid_controllers = []
        for desc_str in desc_strs:
            chain = PIDaisyChain(self, desc_str)
            try:
                await chain.test_open()

                # a daisy-chain master
                await chain.open()
                # iterate over member index
                n_members = await chain.get_property("number_of_members")
                logger.info(f"found {n_members} member(s)")
                for index in range(1, n_members + 1):
                    try:
                        logger.debug(f".. index: {index}")
                        device = PIDaisyController(chain, index)
                        await device.test_open()
                        valid_controllers.append(device)
                    except UnsupportedDeviceError:
                        pass
                await chain.close()
            except UnsupportedDeviceError:
                # rebuild an independent controller
                device = PIController(self, desc_str)
                try:
                    await device.test_open()
                    valid_controllers.append(device)
                except UnsupportedDeviceError:
                    pass

        valid_axes = []
        for controller in valid_controllers:
            await controller.open()
            try:
                valid_axes.extend(await controller.enumerate_axes())
            finally:
                await controller.close()
        return tuple(valid_axes)

    ##

    @property
    def api(self):
        return self._api
