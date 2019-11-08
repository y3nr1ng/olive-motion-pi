import errno
import logging
import os
from pprint import pprint
from timeit import timeit

import coloredlogs
import imageio
import numpy as np
from vispy import app, scene

from olive.drivers.dcamapi import DCAMAPI

coloredlogs.install(
    level="DEBUG", fmt="%(asctime)s %(levelname)s %(message)s", datefmt="%H:%M:%S"
)

logger = logging.getLogger(__name__)

# init driver
driver = DCAMAPI()
driver.initialize()

# init viewer
canvas = scene.SceneCanvas(keys="interactive")
canvas.size = 768, 768

# create view and image
view = canvas.central_widget.add_view()

# lock view
view.camera = scene.PanZoomCamera(aspect=1, interactive=True)
view.camera.flip = (0, 1, 0)


def dump_properties(camera):
    # dump properties
    for name in camera.enumerate_properties():
        print(f"{name} ({camera._get_property_id(name)}) = {camera.get_property(name)}")
        pprint(camera._get_property_attributes(name))
        print()


try:
    devices = driver.enumerate_devices()
    pprint(devices)

    camera = devices[0]

    camera.open()
    canvas.title = str(camera.info)

    try:
        t_exp = 30

        camera.set_max_memory_size(2048 * (2 ** 20))  # 1000 MiB

        camera.set_exposure_time(t_exp)
        camera.set_roi(shape=(2048, 2048))

        # dump_properties(camera)

        if False:
            frame = camera.snap()
            print(f"captured size {frame.shape}, {frame.dtype}")
            imageio.imwrite("debug.tif", frame)
        elif True:
            dst_dir = "_debug"  # 'E:/_debug'

            try:
                os.mkdir(dst_dir)
            except FileExistsError:
                pass

            n_frames = (60 * 1000) // t_exp
            # for i, frame in enumerate(camera.sequence(n_frames)):
            #    imageio.imwrite(os.path.join("E:/_debug", f"frame{i:05d}.tif"), frame)

            import asyncio

            async def grabber(camera, queue, n_frames):
                camera.start_acquisition()
                for i in range(n_frames):
                    logger.info(f".. read frame {i:05d}")
                    frame = camera.get_image(copy=False)
                    await queue.put((i, frame))
                    await asyncio.sleep(0)
                camera.stop_acquisition()

            async def writer(queue):
                while True:
                    i, frame = await queue.get()
                    logger.info(f".. write frame {i:05d}")
                    imageio.imwrite(os.path.join(dst_dir, f"frame{i:05d}.tif"), frame)
                    queue.task_done()
                    await asyncio.sleep(0)

            async def run(n_frames):
                queue = asyncio.Queue(maxsize=len(camera.buffer.frames) // 2)
                consumer = asyncio.ensure_future(writer(queue))
                await grabber(camera, queue, n_frames)
                await queue.join()
                consumer.cancel()

            camera.configure_acquisition(n_frames)

            loop = asyncio.get_event_loop()
            loop.run_until_complete(run(n_frames))
            loop.close()

            camera.unconfigure_acquisition()

        # image = scene.visuals.Image(frame, parent=view.scene, cmap="grays")
        # view.camera.set_range(margin=0)
    finally:
        camera.close()
finally:
    driver.shutdown()

# run loop
# canvas.show()
# app.run()
