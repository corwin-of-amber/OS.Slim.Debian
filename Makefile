repo_main = http://ftp.us.debian.org/debian/pool/main
repo_updates = http://security.debian.org/debian-security/pool/updates/main

kernel_uri = $(repo_main)/l/linux-signed-amd64/linux-image-4.19.0-9-amd64_4.19.118-2_amd64.deb

netboot_uri = http://ftp.us.debian.org/debian/dists/buster/main/installer-amd64/current/images/netboot/netboot.tar.gz
netboot_gtk_uri = http://ftp.us.debian.org/debian/dists/buster/main/installer-amd64/current/images/netboot/gtk/netboot.tar.gz

busybox_apps =  ar       cat      cp       insmod   ln       ls      \
			    modprobe mv       rm       sh       udhcpc   wget    \
			    chroot   depmod   ip       logger   mkdir    mount   \
			    ping     sed      sync     tar      unxz
	

download/kernel:
	mkdir -p $@
	wget -O- $(kernel_uri) | tar xf - -O data.tar.xz | tar xf - -C $@

download/initrd.gz:
	mkdir -p ${dir $@}
	wget -O- $(netboot_uri) | tar xf - -O debian-installer/amd64/initrd.gz > $@
	#cat netboot.tar.gz | tar xf - -O debian-installer/amd64/initrd.gz > $@

download/initrd-gtk.gz:
	mkdir -p ${dir $@}
	wget -O- $(netboot_gtk_uri) | tar xf - -O debian-installer/amd64/initrd.gz > $@

build/busy: download/initrd.gz busy.filelist rdinit
	rm -rf $@
	mkdir -p $@
	tar xf download/initrd.gz --files-from busy.filelist -C $@
	cp rdinit $@/init
	( cd $@/bin && for a in $(busybox_apps) ; do ln -s busybox $$a ; done )

build/busy-hd: download/initrd.gz busy.filelist hd.filelist rdinit
	rm -rf $@
	mkdir -p $@
	tar xf download/initrd.gz --files-from busy.filelist -C $@
	cat hd.filelist | ( cd download/kernel && cpio -dp ../../$@ )
	cp rdinit $@/init
	( cd $@/bin && for a in $(busybox_apps) ; do ln -s busybox $$a ; done )

build/boot: build/busy-hd rootfs/boot/syslinux/syslinux.cfg download/kernel
	rm -rf $@
	mkdir -p $@
	( cd build/busy-hd && find * | cpio -o -H newc 2>/dev/null ) > $@/busy.cpio
	cp -pr rootfs/boot/syslinux $@/
	cp download/kernel/boot/vmlinuz* $@/

build/lib: download/kernel drivers.filelist
	rm -rf $@
	mkdir -p ${dir $@}
	cat drivers.filelist | ( cd download/kernel && cpio -dp ../../${dir $@} )

build/etc: rootfs/etc/inittab rootfs/etc/init.d/rcS
	rm -rf $@
	mkdir -p $@
	cp -pr rootfs/etc/inittab rootfs/etc/init.d $@/

build/installer.cpio: build/busy build/boot build/lib build/etc debian-slim.tar
	tar cf build/busy/boot.tar -C build boot lib etc
	cp debian-slim.tar build/busy/
	( cd build/busy && find * | cpio -o -H newc 2>/dev/null ) > $@

build/busy.cpio: build/busy
	( cd build/busy && find * | cpio -o -H newc 2>/dev/null ) > $@


build/x: download/initrd-gtk.gz xorg-minimal.filelist
	rm -rf $@
	mkdir -p $@
	tar xf download/initrd-gtk.gz -C $@ --files-from xorg-minimal.filelist

build/xorg-minimal.tar: build/x xorg-minimal.filelist
	tar cf $@ --no-xattrs -C build/x --files-from xorg-minimal.filelist
