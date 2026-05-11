################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/lw_usb/HID.c \
../src/lw_usb/MAX3421E.c \
../src/lw_usb/transfer.c 

OBJS += \
./src/lw_usb/HID.o \
./src/lw_usb/MAX3421E.o \
./src/lw_usb/transfer.o 

C_DEPS += \
./src/lw_usb/HID.d \
./src/lw_usb/MAX3421E.d \
./src/lw_usb/transfer.d 


# Each subdirectory must supply rules for building sources it contributes
src/lw_usb/%.o: ../src/lw_usb/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: MicroBlaze gcc compiler'
	mb-gcc -Wall -O0 -g3 -c -fmessage-length=0 -MT"$@" -IC:/Users/tingw/driving_simulator/driving_simulator_sdk/mb_usb_hdmi_top/export/mb_usb_hdmi_top/sw/mb_usb_hdmi_top/standalone_microblaze_0/bspinclude/include -mno-xl-reorder -mlittle-endian -mxl-barrel-shift -mxl-pattern-compare -mcpu=v11.0 -mno-xl-soft-mul -Wl,--no-relax -ffunction-sections -fdata-sections -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


