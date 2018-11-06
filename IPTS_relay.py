#!/usr/bin/env python3
# -*-coding:utf-8-*-

from __future__ import print_function

import sys
import smbus
import signal

bus = smbus.SMBus(1)
NUM_RELAY_PORTS = 4
DEVICE_ADDRESS = 0x20
DEVICE_REG_MODE1 = 0x06
DEVICE_REG_DATA = 0xff


def relay_on(relay_num):
    global DEVICE_ADDRESS
    global DEVICE_REG_DATA
    global DEVICE_REG_MODE1

    if isinstance(relay_num, int):
        if 0 < relay_num <= NUM_RELAY_PORTS:
            print('Turning relay', relay_num, 'ON')
            DEVICE_REG_DATA &= ~(0x1 << (relay_num - 1))
            bus.write_byte_data(DEVICE_ADDRESS, DEVICE_REG_MODE1, DEVICE_REG_DATA)
        else:
            print('Invalid relay #:', relay_num)
    else:
        print('Relay number must be an Integer value')


def relay_off(relay_num):
    global DEVICE_ADDRESS
    global DEVICE_REG_DATA
    global DEVICE_REG_MODE1

    if isinstance(relay_num, int):
        if 0 < relay_num <= NUM_RELAY_PORTS:
            print('Turning relay', relay_num, 'OFF')
            DEVICE_REG_DATA |= (0x1 << (relay_num - 1))
            bus.write_byte_data(DEVICE_ADDRESS, DEVICE_REG_MODE1, DEVICE_REG_DATA)
        else:
            print('Invalid relay #:', relay_num)
    else:
        print('Relay number must be an Integer value')


def relay_all_on():
    global DEVICE_ADDRESS
    global DEVICE_REG_DATA
    global DEVICE_REG_MODE1

    print('Turning all relays ON')
    DEVICE_REG_DATA &= ~(0xf << 0)
    bus.write_byte_data(DEVICE_ADDRESS, DEVICE_REG_MODE1, DEVICE_REG_DATA)


def relay_all_off():
    global DEVICE_ADDRESS
    global DEVICE_REG_DATA
    global DEVICE_REG_MODE1

    print('Turning all relays OFF')
    DEVICE_REG_DATA |= (0xf << 0)
    bus.write_byte_data(DEVICE_ADDRESS, DEVICE_REG_MODE1, DEVICE_REG_DATA)


def relay_toggle_port(relay_num):
    print('Toggling relay:', relay_num)
    if relay_get_port_status(relay_num):
        # it's on, so retain it on
        print("Previous status:")
        relay_on(relay_num)
    else:
        # it's off, so retain it off
        print("Previous status:")
        relay_off(relay_num)


def relay_get_port_status(relay_num):
    # determines whether the specified port is ON/OFF
    global DEVICE_REG_DATA
    print('Checking status of relay', relay_num)
    res = relay_get_port_data(relay_num)
    if res > 0:
        mask = 1 << (relay_num - 1)
        # return the specified bit status
        # return (DEVICE_REG_DATA & mask) != 0
        return (DEVICE_REG_DATA & mask) == 0
    else:
        # otherwise (invalid port), always return False
        print("Specified relay port is invalid")
        return False


def relay_get_port_data(relay_num):
    # gets the current byte value stored in the relay board
    global DEVICE_REG_DATA
    print('Reading relay status value for relay', relay_num)
    # do we have a valid port?
    if 0 < relay_num <= NUM_RELAY_PORTS:
        # read the memory location
        DEVICE_REG_DATA = bus.read_byte_data(DEVICE_ADDRESS, DEVICE_REG_MODE1)
        # return the specified bit status
        return DEVICE_REG_DATA
    else:
        # otherwise (invalid port), always return 0
        print("Specified relay port is invalid")
        return 0


def endProcess(signalnum=None, handler=None):
    relay_all_off()
    sys.exit()


signal.signal(signal.SIGINT, endProcess)
status = str(sys.argv[1])
port = int(sys.argv[2])

try:
    relay_toggle_port(port)
    if status == 'on':
        relay_on(port)
    if status == 'off':
        relay_off(port)
except (OSError, IndexError, TypeError) as reason:
    print('error is :' + str(reason))		
