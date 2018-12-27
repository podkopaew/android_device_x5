#!/system/bin/sh

vndk="$(getprop persist.sys.vndk)"
setprop sys.usb.ffs.aio_compat true

fixSPL() {
    if [ "$(getprop ro.product.cpu.abi)" == "armeabi-v7a" ];then
	    setprop ro.keymaster.mod 'AOSP on ARM32'
    else
	    setprop ro.keymaster.mod 'AOSP on ARM64'
    fi
    img="$(find /dev/block -type l -name kernel$(getprop ro.boot.slot_suffix) |grep by-name |head -n 1)"
    [ -z "$img" ] && img="$(find /dev/block -type l -name boot$(getprop ro.boot.slot_suffix) |grep by-name |head -n 1)"
    if [ -n "$img" ];then
        #Rewrite SPL/Android version if needed
        Arelease="$(getSPL $img android)"
        setprop ro.keymaster.xxx.release "$Arelease"
        setprop ro.keymaster.xxx.security_patch "$(getSPL $img spl)"

        for f in \
		/vendor/lib64/hw/android.hardware.keymaster@3.0-impl-qti.so /vendor/lib/hw/android.hardware.keymaster@3.0-impl-qti.so \
		/system/lib64/vndk-26/libsoftkeymasterdevice.so /vendor/bin/teed \
		/system/lib64/vndk/libsoftkeymasterdevice.so /system/lib/vndk/libsoftkeymasterdevice.so \
		/system/lib/vndk-26/libsoftkeymasterdevice.so \
		/system/lib/vndk-27/libsoftkeymasterdevice.so /system/lib64/vndk-27/libsoftkeymasterdevice.so \
		;do
            [ ! -f $f ] && continue
            ctxt="$(ls -lZ $f |grep -oE 'u:object_r:[^:]*:s0')"
            b="$(echo "$f"|tr / _)"

            cp -a $f /mnt/phh/$b
            sed -i \
		    -e 's/ro.build.version.release/ro.keymaster.xxx.release/g' \
		    -e 's/ro.build.version.security_patch/ro.keymaster.xxx.security_patch/g' \
		    -e 's/ro.product.model/ro.keymaster.mod/g' \
		    /mnt/phh/$b
            chcon "$ctxt" /mnt/phh/$b
            mount -o bind /mnt/phh/$b $f
        done
        if [ "$(getprop init.svc.keymaster-3-0)" == "running" ];then
		setprop ctl.restart keymaster-3-0
	fi
        if [ "$(getprop init.svc.teed)" == "running" ];then
		setprop ctl.restart teed
	fi
    fi
}

 
if mount -o remount,rw /system;then
	resize2fs $(grep ' /system ' /proc/mounts |cut -d ' ' -f 1) || true
elif mount -o remount,rw /;then
	resize2fs /dev/root || true
fi
mount -o remount,ro /system || true
mount -o remount,ro / || true

mkdir -p /mnt/phh/
mount -t tmpfs -o rw,nodev,relatime,mode=755,gid=0 none /mnt/phh || true
mkdir /mnt/phh/empty_dir

fixSPL

setprop persist.sys.overlay.nightmode false
setprop persist.sys.overlay.wifi5g true

if grep -qF 'mkdir /data/.fps 0770 system fingerp' vendor/etc/init/hw/init.mmi.rc;then
    mkdir -p /data/.fps
    chmod 0770 /data/.fps
    chown system:9015 /data/.fps

    chown system:9015 /sys/devices/soc/soc:fpc_fpc1020/irq
    chown system:9015 /sys/devices/soc/soc:fpc_fpc1020/irq_cnt
fi

for f in /vendor/lib/mtk-ril.so /vendor/lib64/mtk-ril.so /vendor/lib/libmtk-ril.so /vendor/lib64/libmtk-ril.so;do
    [ ! -f $f ] && continue
    ctxt="$(ls -lZ $f |grep -oE 'u:object_r:[^:]*:s0')"
    b="$(echo "$f"|tr / _)"

    cp -a $f /mnt/phh/$b
    sed -i \
        -e 's/AT+EAIC=2/AT+EAIC=3/g' \
        /mnt/phh/$b
    chcon "$ctxt" /mnt/phh/$b
    mount -o bind /mnt/phh/$b $f
done

mount -o bind /system/phh/empty /vendor/overlay/SysuiDarkTheme/SysuiDarkTheme.apk || true
mount -o bind /system/phh/empty /vendor/overlay/SysuiDarkTheme/SysuiDarkThemeOverlay.apk || true

mount -o bind /mnt/phh/empty_dir /vendor/etc/audio || true