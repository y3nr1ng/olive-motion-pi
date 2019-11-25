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
    # init driver
    driver = GCS2()
    driver.initialize()

    try:
        axis = await driver.enumerate_devices()
        for axes in axis:
            print(axes.info)
            print("> home")
            await axes.home()
            print("> set_relative_position")
            for _ in range(10):
                await axes.set_relative_position(1)
    finally:
        driver.shutdown()


if __name__ == "__main__":
    trio.run(main)
