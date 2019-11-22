import logging
from pprint import pprint

import coloredlogs

from olive.drivers.pi import GCS2

coloredlogs.install(
    level="DEBUG", fmt="%(asctime)s %(levelname)s %(message)s", datefmt="%H:%M:%S"
)

logger = logging.getLogger(__name__)

# init driver
driver = GCS2()
driver.initialize()

try:
    axis = driver.enumerate_devices()
    for axes in axis:
        print(axes.info)
        print("> home")
        axes.home()
        print("> set_relative_position")
        axes.set_relative_position(1080)
        axes.wait()
finally:
    driver.shutdown()
