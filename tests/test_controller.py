import errno
import logging
import os
from pprint import pprint
from timeit import timeit

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
    devices = driver.enumerate_devices()
    pprint(devices)
finally:
    driver.shutdown()
