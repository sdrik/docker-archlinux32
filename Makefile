DOCKER_USER:=sdrik
DOCKER_ORGANIZATION=sdrik
DOCKER_IMAGE:=archlinux32

rootfs:
	$(eval TMPDIR := $(shell mktemp -d))
	cp /usr/share/devtools/pacman-extra.conf rootfs/etc/pacman.conf
	sed -i 's/^Architecture *=.*/Architecture = i686/' rootfs/etc/pacman.conf
	sed -i 's,\(/etc/pacman\.d/mirrorlist\),rootfs\1,' rootfs/etc/pacman.conf
	cat pacman-conf.d-noextract.conf >> rootfs/etc/pacman.conf
	env -i pacstrap -C rootfs/etc/pacman.conf -c -d -G -M $(TMPDIR) $(shell cat packages)
	cp --recursive --preserve=timestamps --backup --suffix=.pacnew rootfs/* $(TMPDIR)/
	sed -i 's,rootfs\(/etc/pacman\.d/mirrorlist\),\1,' $(TMPDIR)/etc/pacman.conf
	arch-chroot $(TMPDIR) locale-gen
	arch-chroot $(TMPDIR) pacman-key --init
	arch-chroot $(TMPDIR) pacman-key --populate archlinux32
	tar --numeric-owner --xattrs --acls --exclude-from=exclude -C $(TMPDIR) -c . -f archlinux.tar
	rm -rf $(TMPDIR)

docker-image: rootfs
	docker build -t $(DOCKER_ORGANIZATION)/$(DOCKER_IMAGE) .

docker-image-test: docker-image
	# FIXME: /etc/mtab is hidden by docker so the stricter -Qkk fails
	docker run --rm $(DOCKER_ORGANIZATION)/$(DOCKER_IMAGE) sh -c "/usr/bin/pacman -Sy && /usr/bin/pacman -Qqk"
	docker run --rm $(DOCKER_ORGANIZATION)/$(DOCKER_IMAGE) sh -c "/usr/bin/pacman -Syu --noconfirm docker && docker -v"
	# Ensure that the image does not include a private key
	! docker run --rm $(DOCKER_ORGANIZATION)/$(DOCKER_IMAGE) pacman-key --lsign-key pierre@archlinux.de
	docker run --rm $(DOCKER_ORGANIZATION)/$(DOCKER_IMAGE) sh -c "/usr/bin/id -u http"
	docker run --rm $(DOCKER_ORGANIZATION)/$(DOCKER_IMAGE) sh -c "/usr/bin/pacman -Syu --noconfirm grep && locale | grep -q UTF-8"

ci-test:
	docker run --rm --privileged --tmpfs=/tmp:exec --tmpfs=/run/shm -v /run/docker.sock:/run/docker.sock \
		-v $(PWD):/app -w /app $(DOCKER_ORGANIZATION)/$(DOCKER_IMAGE) \
		sh -c 'pacman -Syu --noconfirm make devtools docker && make docker-image-test'

docker-push:
	docker login -u $(DOCKER_USER)
	docker push $(DOCKER_ORGANIZATION)/$(DOCKER_IMAGE)

.PHONY: rootfs docker-image docker-image-test ci-test docker-push
