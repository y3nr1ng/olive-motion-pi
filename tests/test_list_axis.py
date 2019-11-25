import logging
from pprint import pprint

import coloredlogs
import trio

from olive.drivers.pi import GCS2

coloredlogs.install(
    level="DEBUG", fmt="%(asctime)s %(levelname)s %(message)s", datefmt="%H:%M:%S"
)

logger = logging.getLogger(__name__)


async def main():
    driver = GCS2()

    try:
        # init driver
        await driver.initialize()

        # iterate over valid devices
        axes = await driver.enumerate_devices()
        for axis in axes:
            print(axis.info)
            print("> home")
            await axis.home()
            limits = await axis.get_limits()
            print(f"> limits {limits}")
            print("> set_relative_position")
            for _ in range(10):
                await axis.set_relative_position(1)
    finally:
        await driver.shutdown()


if __name__ == "__main__":
    trio.run(main)
