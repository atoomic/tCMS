SHELL := /bin/bash

.PHONY: depend
depend:
	[ -f "/etc/debian_version" ] && make prereq-debs; /bin/true;
	make prereq-perl prereq-frontend

.PHONY: install
install:
	test -d www/themes || mkdir -p www/themes
	test -d data/files || mkdir -p data/files
	test -d www/assets || mkdir -p www/assets
	test -d www/statics || mkdir -p www/statics
	test -d totp/ || mkdir -p totp
	test -d ~/.tcms || mkdir ~/.tcms
	test -d /var/log && mkdir /var/log/www; /bin/true
	$(RM) pod2htmd.tmp;

.PHONY: install-service
install-service:
	mkdir -p ~/.config/systemd/user
	cp service-files/systemd.unit ~/.config/systemd/user/tCMS.service
	sed -ie 's#__REPLACEME__#$(shell pwd)#g' ~/.config/systemd/user/tCMS.service
	sed -ie 's#__PORT__#$(PORT)#g' ~/.config/systemd/user/tCMS.service
	systemctl --user daemon-reload
	systemctl --user enable tCMS
	systemctl --user start tCMS
	loginctl enable-linger $(USER)

.PHONY: prereq-debian
prereq-debian: prereq-debs prereq-perl prereq-frontend prereq-node

.PHONY: prereq-debs
prereq-debs:
	sudo apt-get update
	sudo apt-get install -y sqlite3 nodejs npm libsqlite3-dev libdbd-sqlite3-perl cpanminus starman libxml2 curl         \
		uwsgi uwsgi-plugin-psgi fail2ban nginx certbot\
	    libtext-xslate-perl libplack-perl libconfig-tiny-perl libdatetime-format-http-perl libjson-maybexs-perl          \
	    libuuid-tiny-perl libcapture-tiny-perl libconfig-simple-perl libdbi-perl libfile-slurper-perl libfile-touch-perl \
	    libfile-copy-recursive-perl libxml-rss-perl libmodule-install-perl libio-string-perl                             \
	    libmoose-perl libmoosex-types-datetime-perl libxml-libxml-perl liblist-moreutils-perl libclone-perl libpath-tiny-perl

.PHONY: prereq-perl
prereq-perl:
	sudo cpanm -n --installdeps .

.PHONY: prereq-node
prereq-node:
	npm i

.PHONY: prereq-frontend
prereq-frontend:
	mkdir -p www/scripts; pushd www/scripts && curl -L --remote-name-all                                 \
		"https://raw.githubusercontent.com/chalda-pnuzig/emojis.json/master/dist/list.min.json"     \
		"https://raw.githubusercontent.com/highlightjs/cdn-release/main/build/highlight.min.js"; popd
	mkdir -p www/styles; cd www/styles && curl -L --remote-name-all \
		"https://raw.githubusercontent.com/highlightjs/cdn-release/main/build/styles/obsidian.min.css"

.PHONY: reset
reset: reset-remove install

.PHONY: reset-remove
reset-remove:
	rm -rf data; /bin/true
	rm -rf www/themes; /bin/true
	rm -rf www/assets; /bin/true
	rm config/auth.db; /bin/true
	rm config/main.cfg; /bin/true
	rm config/has_users; /bin/true
	rm config/setup; /bin/true

.PHONY: fail2ban
fail2ban:
	sudo ln -sr fail2ban/tcms-jail.conf   /etc/fail2ban/jail.d/tcms.conf
	sudo ln -sr fail2ban/tcms-filter.conf /etc/fail2ban/filter.d/tcms.conf

.PHONY: nginx
nginx:
	[ -n "$$SERVER_NAME" ] || ( echo "Please set the SERVER_NAME environment variable before running (e.g. test.test)" && /bin/false )
	[ -n "$$SERVER_PORT" ] || ( echo "Please set the SERVER_PORT environment variable before running (e.g. 5000)" && /bin/false )
	sed 's/\%SERVER_NAME\%/$(SERVER_NAME)/g' nginx/tcms.conf.tmpl > nginx/tcms.conf.intermediate
	sed 's/\%SERVER_PORT\%/$(SERVER_PORT)/g' nginx/tcms.conf.intermediate > nginx/tcms.conf
	rm nginx/tcms.conf.intermediate
	mkdir -p '/var/www/$(SERVER_NAME)'
	mkdir -p '/var/www/$(SERVER_NAME)'
	ln -sr nginx/tcms.conf '/etc/nginx/sites-enabled/$(SERVER_NAME).conf'
	openssl req -x509 -nodes -newkey -in '$(SERVER_NAME)' rsa:4096 -keyout key.pem -out cert.pem -days 365
	openssl req -x509 -nodes -newkey -in '$(SERVER_NAME)' rsa:4096 -keyout key.pem -out cert.pem -days 365
	certbot certonly --webroot -w '/var/www/$(SERVER_NAME)/' -d '$(SERVER_NAME)' -d 'www.$(SERVER_NAME)' -w '/var/www/mail.$(SERVER_NAME)' -d 'mail.$(SERVER_NAME)'
	systemctl restart nginx
	systemctl restart dovecot
	systemctl restart postfix
