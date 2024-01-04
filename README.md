# rk1-image
Custom script to build the OS image for Fula Tower plus (RK1-Armbian). This repository creates the image for FxBlox RK1 tower. The latest image can be found attached to the latest release.
The file can be used to image the FxBlox RK1.


### Run

This part is <b>unnecessary</b> to image the FxBlox as the latest image is always available in the release section. this is just for developers who are interested in building an image themselves.
```shell
sudo sh build_image.sh
```

### Image the FxBlox RK1

1- Download the update.zip file attached to the <b>Assets</b> section of the [latest release](https://github.com/functionland/rk1-image/releases/latest)
 
2- Unzip it to the root of a USBC drive which is formatted as FAT32 (unzipped files Should be directly in the root) 
 
3- Turn off FxBlox 
 
4- Connect the USB disk to the top USB port of Blox (just the top one is designed for boot) 
 
5- Turn on blox and the LED should turn green, blue, and then yellowish which means it is updating 
 
6- After about 15 minutes, the LED starts blinking green and blue, at this point remove the flash drive from the top USB port and restart by unplugging and plugging back.  
 
7- You should be able to turn it on and set it up from zero (on the first turn on, it might automatically reboot twice)

- After Attaching the USB:

https://github.com/functionland/rk1-image/assets/6176518/06ddf8ed-61a0-4031-b48d-77f7f7ba79eb

- After 15 minutes:

https://github.com/functionland/rk1-image/assets/6176518/71d42e46-1cc8-4ab7-b573-a11eeaea3289



