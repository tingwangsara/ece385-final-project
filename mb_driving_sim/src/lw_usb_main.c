#include <stdio.h>
#include "platform.h"
#include "lw_usb/GenericMacros.h"
#include "lw_usb/GenericTypeDefs.h"
#include "lw_usb/MAX3421E.h"
#include "lw_usb/USB.h"
#include "lw_usb/usb_ch9.h"
#include "lw_usb/transfer.h"
#include "lw_usb/HID.h"

#include "xparameters.h"
#include <xgpio.h>

#include "xuartlite.h" //for steering wheel

extern HID_DEVICE hid_device;

static XGpio Gpio_hex;
static XUartLite Uart; //for steering wheel
static BYTE addr = 1; 				//hard-wired USB address
const char* const devclasses[] = { " Uninitialized", " HID Keyboard", " HID Mouse", " Mass storage" };

// modified for ddr3
#define PKT_NONE       0x00
#define PKT_WHEEL      0xA1
#define PKT_IMAGE      0xB1
#define PKT_IMAGE_DONE 0xE1

static u8 pkt_type = PKT_NONE;
static u8 pkt_buf[8];
static int pkt_idx = 0;
static u32 image_word_count = 0;

static XGpio Gpio_img_data;
static XGpio Gpio_img_ctrl;
static u32 img_toggle = 0;

void handle_uart_byte(u8 byte) {
    if (pkt_type == PKT_NONE) {
        if (byte == PKT_WHEEL || byte == PKT_IMAGE || byte == PKT_IMAGE_DONE) {
            pkt_type = byte;
            pkt_idx = 0;

            if (byte == PKT_IMAGE_DONE) {
                xil_printf("Image done, words = %d\n", image_word_count);
                XGpio_DiscreteWrite(&Gpio_img_ctrl, 1, img_toggle | 0x2);
                pkt_type = PKT_NONE;
            }
        }
        return;
    }

    if (pkt_type == PKT_WHEEL) {
        pkt_buf[pkt_idx++] = byte;

        if (pkt_idx == 2) {
            u32 out = pkt_buf[0] | (pkt_buf[1] << 8);
            printHex(out, 1);

            pkt_type = PKT_NONE;
            pkt_idx = 0;
        }
    }

    else if (pkt_type == PKT_IMAGE) {
        pkt_buf[pkt_idx++] = byte;

        if (pkt_idx == 8) {

            u32 lo = pkt_buf[0] |
                     (pkt_buf[1]<<8) |
                     (pkt_buf[2]<<16) |
                     (pkt_buf[3]<<24);

            u32 hi = pkt_buf[4] |
                     (pkt_buf[5]<<8) |
                     (pkt_buf[6]<<16) |
                     (pkt_buf[7]<<24);

            // write image data
            XGpio_DiscreteWrite(&Gpio_img_data, 1, lo);
            XGpio_DiscreteWrite(&Gpio_img_data, 2, hi);

            // toggle valid
            img_toggle ^= 1;
            XGpio_DiscreteWrite(&Gpio_img_ctrl, 1, img_toggle);

            image_word_count++;

            pkt_type = PKT_NONE;
            pkt_idx = 0;
        }
    }
}
// modified for ddr3 endsF

BYTE GetDriverandReport() {
	BYTE i;
	BYTE rcode;
	BYTE device = 0xFF;
	BYTE tmpbyte;

	DEV_RECORD* tpl_ptr;
	xil_printf("Reached USB_STATE_RUNNING (0x40)\n");
	for (i = 1; i < USB_NUMDEVICES; i++) {
		tpl_ptr = GetDevtable(i);
		if (tpl_ptr->epinfo != NULL) {
			xil_printf("Device: %d", i);
			xil_printf("%s \n", devclasses[tpl_ptr->devclass]);
			device = tpl_ptr->devclass;
		}
	}
	//Query rate and protocol
	rcode = XferGetIdle(addr, 0, hid_device.interface, 0, &tmpbyte);
	if (rcode) {   //error handling
		xil_printf("GetIdle Error. Error code: ");
		xil_printf("%x \n", rcode);
	} else {
		xil_printf("Update rate: ");
		xil_printf("%x \n", tmpbyte);
	}
	xil_printf("Protocol: ");
	rcode = XferGetProto(addr, 0, hid_device.interface, &tmpbyte);
	if (rcode) {   //error handling
		xil_printf("GetProto Error. Error code ");
		xil_printf("%x \n", rcode);
	} else {
		xil_printf("%d \n", tmpbyte);
	}
	return device;
}

void printHex (u32 data, unsigned channel)
{
	XGpio_DiscreteWrite (&Gpio_hex, channel, data);
}

int main() {
    init_platform();
    XUartLite_Initialize(&Uart, XPAR_AXI_UARTLITE_0_DEVICE_ID);	//for steering wheel
    XGpio_Initialize(&Gpio_hex, XPAR_GPIO_USB_KEYCODE_DEVICE_ID);
   	XGpio_SetDataDirection(&Gpio_hex, 1, 0x00000000); //configure hex display GPIO
   	XGpio_SetDataDirection(&Gpio_hex, 2, 0x00000000); //configure hex display GPIO

   	// for ddr3 begins
   	XGpio_Initialize(&Gpio_img_data, XPAR_AXI_GPIO_IMG_DATA_DEVICE_ID);
   	XGpio_SetDataDirection(&Gpio_img_data, 1, 0x00000000);
   	XGpio_SetDataDirection(&Gpio_img_data, 2, 0x00000000);

   	XGpio_Initialize(&Gpio_img_ctrl, XPAR_AXI_GPIO_IMG_CTRL_DEVICE_ID);
   	XGpio_SetDataDirection(&Gpio_img_ctrl, 1, 0x00000000);

   	// for ddr3 ends


   	BYTE rcode;
	BOOT_MOUSE_REPORT buf;		//USB mouse report
	BOOT_KBD_REPORT kbdbuf;

	BYTE runningdebugflag = 0;//flag to dump out a bunch of information when we first get to USB_STATE_RUNNING
	BYTE errorflag = 0; //flag once we get an error device so we don't keep dumping out state info
	BYTE device;

	xil_printf("initializing MAX3421E...\n");
	MAX3421E_init();
	xil_printf("initializing USB...\n");
	USB_init();
	while (1) {
		u8 byte;

		    while (XUartLite_Recv(&Uart, &byte, 1) > 0) {
		        handle_uart_byte(byte);
		    }

		xil_printf("."); //A tick here means one loop through the USB main handler
		MAX3421E_Task();
		USB_Task();
		if (GetUsbTaskState() == USB_STATE_RUNNING) {
			if (!runningdebugflag) {
				runningdebugflag = 1;
				device = GetDriverandReport();
			} else if (device == 1) {
				//run keyboard debug polling
				rcode = kbdPoll(&kbdbuf);
				if (rcode == hrNAK) {
					continue; //NAK means no new data
				} else if (rcode) {
					xil_printf("Rcode: ");
					xil_printf("%x \n", rcode);
					continue;
				}
				xil_printf("keycodes: ");
				for (int i = 0; i < 6; i++) {
					xil_printf("%x ", kbdbuf.keycode[i]);
				}
				//Outputs the first 4 keycodes using the USB GPIO channel 1
				printHex (kbdbuf.keycode[0] + (kbdbuf.keycode[1]<<8) + (kbdbuf.keycode[2]<<16) + + (kbdbuf.keycode[3]<<24), 1);
				//Modify to output the last 2 keycodes on channel 2.
				xil_printf("\n");
			}

			else if (device == 2) {
				rcode = mousePoll(&buf);
				if (rcode == hrNAK) {
					//NAK means no new data
					continue;
				} else if (rcode) {
					xil_printf("Rcode: ");
					xil_printf("%x \n", rcode);
					continue;
				}
				xil_printf("X displacement: ");
				xil_printf("%d ", (signed char) buf.Xdispl);
				xil_printf("Y displacement: ");
				xil_printf("%d ", (signed char) buf.Ydispl);
				xil_printf("Buttons: ");
				xil_printf("%x\n", buf.button);
			}
		} else if (GetUsbTaskState() == USB_STATE_ERROR) {
			if (!errorflag) {
				errorflag = 1;
				xil_printf("USB Error State\n");
				//print out string descriptor here
			}
		} else //not in USB running state
		{

			xil_printf("USB task state: ");
			xil_printf("%x\n", GetUsbTaskState());
			if (runningdebugflag) {	//previously running, reset USB hardware just to clear out any funky state, HS/FS etc
				runningdebugflag = 0;
				MAX3421E_init();
				USB_init();
			}
			errorflag = 0;
		}

	}
    cleanup_platform();
	return 0;
}
