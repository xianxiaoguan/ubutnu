#!/usr/bin/env python3
# -*-coding:utf-8-*-

import sys
import smbus

bus = smbus.SMBus(1)
NUM_RELAY_PORTS = 4
DEVICE_ADDRESS = 0x20
DEVICE_REG_MODE1 = 0x06
DEVICE_REG_DATA = 0xff


def IPTS_relay(relay_num, relay_status):
    global DEVICE_ADDRESS
    global DEVICE_REG_DATA
    global DEVICE_REG_MODE1
    if relay_status == 'on':
        if isinstance(relay_num, int):
            if 0 < relay_num <= NUM_RELAY_PORTS:
                print('Turning relay', relay_num, 'ON')
                DEVICE_REG_DATA &= ~(0x1 << (relay_num - 1))
                bus.write_byte_data(DEVICE_ADDRESS, DEVICE_REG_MODE1, DEVICE_REG_DATA)
            else:
                print('Invalid relay #:', relay_num)
        else:
            print('Relay number must be an Integer value')
    if relay_status == 'off':
        if isinstance(relay_num, int):
            if 0 < relay_num <= NUM_RELAY_PORTS:
                print('Turning relay', relay_num, 'OFF')
                DEVICE_REG_DATA |= (0x1 << (relay_num - 1))
                bus.write_byte_data(DEVICE_ADDRESS, DEVICE_REG_MODE1, DEVICE_REG_DATA)
            else:
                print('Invalid relay #:', relay_num)
        else:
            print('Relay number must be an Integer value')


status = str(sys.argv[1])
port = int(sys.argv[2])
IPTS_relay(port, status)
