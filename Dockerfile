FROM archlinux:latest as stage1

ARG ARCH=${ARCH:-i686}

COPY rootfs/etc/pacman.d/mirrorlist /etc/pacman.d/

RUN \
	pacman-key --init \
	&& yes | pacman --arch=${ARCH} -Syy archlinux32-keyring-transition \
	&& yes | pacman --arch=${ARCH} -S archlinux32-keyring \
	&& yes | pacman --arch=${ARCH} -Suu \
	&& yes | pacman --arch=${ARCH} -Scc

WORKDIR /root
COPY . .

RUN yes | pacman --arch=${ARCH} -S make devtools
RUN make rootfs
RUN mkdir stage2 && tar --numeric-owner --xattrs --acls -C stage2 -x -f archlinux.tar

FROM scratch
COPY --from=stage1 /root/stage2/ /
ENV LANG=en_US.UTF-8
ENTRYPOINT /usr/bin/linux32
CMD ["/usr/bin/bash"]
