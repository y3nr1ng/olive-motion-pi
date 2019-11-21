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
    devices = driver.enumerate_devices()
    pprint(devices)

    for controller in devices:
        controller.open()
        try:
            print(">>> PARAMETERS")
            pprint(controller.get_property("parameters"))
            print("<<< PARAMETERS")
            print()

            print(controller.enumerate_axes())
        finally:
            controller.close()
finally:
    driver.shutdown()
