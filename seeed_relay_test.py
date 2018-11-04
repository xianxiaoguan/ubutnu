#!/usr/bin/env python

import signal
import sys

import smbus

bus = smbus.SMBus(1)  # 0 = /dev/i2c-0 (port I2C0), 1 = /dev/i2c-1 (port I2C1)


class Relay():
    global bus

    def __init__(self):
        self.DEVICE_ADDRESS = 0x20  # 7 bit address (will be left shifted to add the read write bit)
        self.DEVICE_REG_MODE1 = 0x06
        self.DEVICE_REG_DATA = 0xff
        bus.write_byte_data(self.DEVICE_ADDRESS, self.DEVICE_REG_MODE1, self.DEVICE_REG_DATA)

    def ON_1(self):
        print('ON_1...')
        self.DEVICE_REG_DATA &= ~(0x1 << 0)
        bus.write_byte_data(self.DEVICE_ADDRESS, self.DEVICE_REG_MODE1, self.DEVICE_REG_DATA)

    def ON_2(self):
        print('ON_2...')
        self.DEVICE_REG_DATA &= ~(0x1 << 1)
        bus.write_byte_data(self.DEVICE_ADDRESS, self.DEVICE_REG_MODE1, self.DEVICE_REG_DATA)

    def ON_3(self):
        print('ON_3...')
        self.DEVICE_REG_DATA &= ~(0x1 << 2)
        bus.write_byte_data(self.DEVICE_ADDRESS, self.DEVICE_REG_MODE1, self.DEVICE_REG_DATA)

    def ON_4(self):
        print('ON_4...')
        self.DEVICE_REG_DATA &= ~(0x1 << 3)
        bus.write_byte_data(self.DEVICE_ADDRESS, self.DEVICE_REG_MODE1, self.DEVICE_REG_DATA)

    def OFF_1(self):
        print('OFF_1...')
        self.DEVICE_REG_DATA |= (0x1 << 0)
        bus.write_byte_data(self.DEVICE_ADDRESS, self.DEVICE_REG_MODE1, self.DEVICE_REG_DATA)

    def OFF_2(self):
        print('OFF_2...')
        self.DEVICE_REG_DATA |= (0x1 << 1)
        bus.write_byte_data(self.DEVICE_ADDRESS, self.DEVICE_REG_MODE1, self.DEVICE_REG_DATA)

    def OFF_3(self):
        print('OFF_3...')
        self.DEVICE_REG_DATA |= (0x1 << 2)
        bus.write_byte_data(self.DEVICE_ADDRESS, self.DEVICE_REG_MODE1, self.DEVICE_REG_DATA)

    def OFF_4(self):
        print('OFF_4...')
        self.DEVICE_REG_DATA |= (0x1 << 3)
        bus.write_byte_data(self.DEVICE_ADDRESS, self.DEVICE_REG_MODE1, self.DEVICE_REG_DATA)

    def ALLON(self):
        print('ALL ON...')
        self.DEVICE_REG_DATA &= ~(0xf << 0)
        bus.write_byte_data(self.DEVICE_ADDRESS, self.DEVICE_REG_MODE1, self.DEVICE_REG_DATA)

    def ALLOFF(self):
        print('ALL OFF...')
        self.DEVICE_REG_DATA |= (0xf << 0)
        bus.write_byte_data(self.DEVICE_ADDRESS, self.DEVICE_REG_MODE1, self.DEVICE_REG_DATA)


if __name__ == "__main__":
    relay = Relay()

    # Called on process interruption. Set all pins to "Input" default mode.
    def endProcess(signalnum=None, handler=None):
        relay.ALLOFF()
        sys.exit()


    signal.signal(signal.SIGINT, endProcess)

    status = str(sys.argv[1])
    port = int(sys.argv[2])


    if ( status == 'on' and port == 1 ):
        relay.ON_1()
    elif ( status == 'on' and port == 2 ):
        relay.ON_2()
    elif ( status == 'on' and port == 3 ):
        relay.ON_3()
    elif ( status == 'on' and port == 4 ):
        relay.ON_4()
    elif ( status == 'off' and port == 1 ):
        relay.OFF_1()
    elif ( status == 'off' and port == 2 ):
        relay.OFF_2()
    elif ( status == 'off' and port == 3 ):
        relay.OFF_3()
    elif ( status == 'off' and port == 4 ):
        relay.OFF_4()
    elif ( status == 'on' and port == 5 ):
        relay.ALLON()
    elif( status == 'off' and port == 5 ):
        relay.ALLOFF()
