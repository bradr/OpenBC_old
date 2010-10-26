STATIC_FILES=static/*
INSTALL_DIR=/var/www/openbc
install: $(STATIC_FILE)
	rm -rf $(INSTALL_DIR)/root
	mkdir $(INSTALL_DIR)/root
	cp -R $(STATIC_FILES) $(INSTALL_DIR)/root
	cp -f etc/nginx/sites-available/openbc /etc/nginx/sites-available
	ln -sf /etc/nginx/sites-available/openbc /etc/nginx/sites-enabled/openbc
	/etc/init.d/nginx reload
