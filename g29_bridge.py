import pygame
import serial
import os
import time

os.environ['SDL_VIDEODRIVER'] = 'dummy'
os.environ['SDL_AUDIODRIVER'] = 'dummy'

PORT = "COM4"
BAUD = 115200
IMAGE_FILE = "sky_2048x200_crop_top_word64.mem"

PKT_WHEEL = 0xA1
PKT_IMAGE = 0xB1
PKT_IMAGE_DONE = 0xE1

ser = serial.Serial(PORT, BAUD, timeout=0)
time.sleep(2)

def send_image():
    print("Sending image to FPGA DDR3...")

    count = 0
    with open(IMAGE_FILE, "r") as f:
        for line in f:
            s = line.strip()
            if not s:
                continue

            word = int(s, 16)
            payload = word.to_bytes(8, byteorder="little")

            ser.write(bytes([PKT_IMAGE]) + payload)
            count += 1

            if count % 1000 == 0:
                print("sent words:", count)

            # 115200 baud is slow; tiny pause helps UART parser
            time.sleep(0.002)
    print("Image payload sent, waiting before DONE...")
    time.sleep(0.5)

    ser.write(bytes([PKT_IMAGE_DONE]))
    ser.flush()
    print("Image sent. Total 64-bit words:", count)

def init_wheel():
    pygame.init()
    pygame.joystick.init()

    j = pygame.joystick.Joystick(0)
    j.init()

    print("Connected:", j.get_name())
    print("Sending wheel data to FPGA on", PORT)
    return j

def send_wheel_loop(j):
    while True:
        pygame.event.pump()

        steering = j.get_axis(0)
        gas_axis = j.get_axis(1)
        brake_axis = j.get_axis(2)

        gas   = 1 if gas_axis < -0.5 else 0
        brake = 1 if brake_axis < -0.5 else 0

        LEFT_DEADZONE = 0.08
        RIGHT_DEADZONE = 0.03

        LEFT_MAX = -1.0
        RIGHT_MAX = 0.85

        if steering < 0:
            if abs(steering) < LEFT_DEADZONE:
                norm = 0.0
            else:
                norm = steering / abs(LEFT_MAX)
        else:
            if steering < RIGHT_DEADZONE:
                norm = 0.0
            else:
                norm = steering / RIGHT_MAX

        norm = max(-1.0, min(1.0, norm))
        steer_byte = int((norm + 1.0) * 127.5)

        buttons = (gas << 2) | (brake << 3)

        ser.write(bytes([PKT_WHEEL, buttons, steer_byte]))

        time.sleep(0.02)

if __name__ == "__main__":
    send_image()
    wheel = init_wheel()
    send_wheel_loop(wheel)