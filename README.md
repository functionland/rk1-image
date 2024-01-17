# rk1-image
Custom script to build the OS image for Fula Tower plus (RK1-Armbian). This repository creates the image for FxBlox RK1 tower. The latest image can be found attached to the latest release.
The file can be used to image the FxBlox RK1.


### Run
- Required: No
- Technical level: 6/10
  
This part is <b>unnecessary</b> to image the FxBlox as the latest image is always available in the release section. this is just for developers who are interested in building an image themselves.

for building server images without Desktop GUI run this command.
```shell
bash build_image.sh server
```
for building a full image with Desktop GUI run this command.
```shell
bash build_image.sh desktop
```

### Image the FxBlox RK1
- Required: Yes
- Technical level: 2/10

1- Download the `minimal_update.zip` file attached to the <b>Assets</b> section of the [latest release](https://github.com/functionland/rk1-image/releases/latest) to a folder on your computer
- Only all the ones either without `minimal_` or with `minimal_` and not both. `minimal_` does not have the desktop and GUI available and can be accessed with Terminal but is much smaller. If you need a desktop, download the ones without the `minimal` prefix
- Due to the GitHub size limit the file might be separated into a multi-part zip. Download all files to the same folder and you should be able to unzip with any software
 
2- Unzip the downloaded file on your computer by clicking on `minimal_update.zip` and choosing unzip/extract option, and copy the unzipped files to the root of a USBC drive which is formatted as `FAT32`
- USB must be formatted as `FAT32`
- unzipped files Should be directly in the root
- it is safer if you unzip on your computer first and then copy instead of directly unzipping into the USB due to the `FAT32` file size limit) 
 
3- Turn off FxBlox 
 
4- Connect the USB disk to the top USB port of Blox (just the top one is designed for boot) 
 
5- Turn on blox and the LED should turn green, blue, and then yellowish which means it is updating 
 
6- After about 15 minutes, the LED starts blinking green and blue, at this point remove the flash drive from the top USB port and restart by unplugging and plugging back the power.
- You can plug the USB back into the tower if you want but either remove the files r plug it into another port other than the top one
 
7- You should be able to turn it on and set it up from zero (on the first turn on after the update, it might automatically reboot twice and take about `10 minutes` to show `FxBlox` wifi)

8- The next updates will be pushed automatically when available and there is no need for a manual update

- After Attaching the USB:

https://github.com/functionland/rk1-image/assets/6176518/06ddf8ed-61a0-4031-b48d-77f7f7ba79eb

- After 15 minutes:

https://github.com/functionland/rk1-image/assets/6176518/71d42e46-1cc8-4ab7-b573-a11eeaea3289

### update USB Type-C firmware
- Required: No
- Technical level: 7/10
  
RK1 bottom USB is a full-feature USB Type-C with USB2, USB3, Display Port Output and charger port. For enabling all features we must update its flash firmware manually. For more info see this [link](firmware/README.md)

