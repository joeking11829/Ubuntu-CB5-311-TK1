cd && clear
echo "--------------------------------------------------------"
echo "     Script to re-enable cuda capabilities              "
echo "     on Acer CB5-311 Chromebooks                        "
echo "--------------------------------------------------------"
echo
#echo "install tools"
#sudo apt-get -y install cgpt vboot-kernel-utils device-tree-compiler build-essential u-boot-tools ncurses-dev mpi-default-dev mpi-default-bin

cd $HOME/Downloads
#echo
#echo "fetch sources"
#wget  http://commondatastorage.googleapis.com/chromeos-localmirror/distfiles/xhci-firmware-2014.10.10.00.00.tbz2 
#wget  https://chromium.googlesource.com/chromiumos/third_party/kernel/+archive/release-R41-6680.B-chromeos-3.10.tar.gz
# The CUDA repo to use when we are done:
#wget http://developer.download.nvidia.com/embedded/L4T/r21_Release_v3.0/cuda-repo-l4t-r21.3-6-5-prod_6.5-42_armhf.deb

echo
ls -l xhci-firmware*tbz2 release-R41-6680.B*tar.gz

mkdir -p $HOME/src/linux
cd $HOME/src/linux
echo
echo "copy firmware"
sudo tar xf $HOME/Downloads/xhci-firmware-2014.10.10.00.00.tbz2 -C /
echo
echo "extract kernel"
tar -xf $HOME/Downloads/release-R41-6680.B-chromeos-3.10.tar.gz
echo
ls
echo
echo "configure"
./chromeos/scripts/prepareconfig chromeos-tegra

./scripts/config --set-val CONFIG_EXTRA_FIRMWARE \"nvidia/tegra124/xusb.bin\"
./scripts/config --set-val CONFIG_EXTRA_FIRMWARE_DIR \"/lib/firmware\"
./scripts/config -d CONFIG_CC_STACKPROTECTOR
./scripts/config -d CONFIG_SECURITY_CHROMIUMOS
WIFIVERSION=-3.8 make oldnoconfig
cat ./.config|grep CONFIG_EXTRA_FIRMWARE
echo

WIFIVERSION=-3.8 make -j4 zImage
WIFIVERSION=-3.8 make -j4 modules
WIFIVERSION=-3.8 make tegra124-nyan-big.dtb
sudo WIFIVERSION=-3.8 make INSTALL_PATH=/boot INSTALL_MOD_PATH=/ firmware_install modules_install 

cat << __EOF__ > arch/arm/boot/kernel.its
/dts-v1/;

/ {
    description = "ChromeOS kernel image with one or more FDT-blobs.";
    images {
	    kernel@1{
		    description = "kernel";
		    data = /incbin/("zImage");
		    type = "kernel_noload";
		    arch = "arm";
		    os = "linux";
		    compression = "none";
		    load = <0>;
		    entry = <0>;
	    };
	    fdt@1{
		    description = "tegra124-nyan-big.dtb";
		    data = /incbin/("dts/tegra124-nyan-big.dtb");
		    type = "flat_dt";
		    arch = "arm";
		    compression = "none";
		    hash@1 {
			    algo = "sha1";
		    };
	    };
    };
    configurations {
	    default = "conf@1";
	    conf@1 {
		    kernel = "kernel@1";
		    fdt = "fdt@1";
	    };
    };
};
__EOF__

mkimage -f arch/arm/boot/kernel.its vmlinux.uimg
echo "console=tty1 debug verbose root=/dev/mmcblk0p7 rootfstype=ext4 rootwait rw lsm.module_locking=0" > kernel-config
vbutil_kernel \
    --version 1 \
    --arch arm \
    --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
    --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
    --vmlinuz vmlinux.uimg \
    --pack chromeos-R41-6680.B.kpart \
    --config kernel-config

echo
echo "--------------------------------------------------------"
echo "  We are done. Install kernel now? - Then do:"
echo 
echo "  cd $HOME/src/linux                                    "  
echo "  sudo dd if=chromeos-R41-6680.B.kpart of=/dev/mmcblk0p6"
echo "  sudo cgpt add -i 6 -P 5 -T 1 /dev/mmcblk0             "
echo 
echo "  ... and reboot.                                       "
