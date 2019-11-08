from olive.drivers.dcamapi import DCAMAPI

try:
    camera1 = DCAMAPI()
    camera1.open(0)
    print('cam1 open')
    
    try:
        camera2 = DCAMAPI()
        camera2.open(0)
        print('cam2 open') # should fail
        
        camera2.close()
    finally:
        print('cam2 cleanup')
        camera2.uninit()

    camera1.close()
finally:
    print('cam1 cleanup')
    camera1.uninit()