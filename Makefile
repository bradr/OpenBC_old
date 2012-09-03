STATIC_FILES=static/*
INSTALL_DIR=/var/www/openbc
SOLR_DIR=/var/lib/tomcat6/solr/conf
TOMCAT_DIR=/etc/tomcat6
install: $(STATIC_FILE)
	rm -rf $(INSTALL_DIR)/root
	mkdir $(INSTALL_DIR)/root
	cp -R $(STATIC_FILES) $(INSTALL_DIR)/root
	rm -rf $(INSTALL_DIR)/views
	mkdir $(INSTALL_DIR)/views
	cp -R views/* $(INSTALL_DIR)/views
	cp -R lib template $(INSTALL_DIR)
	cp -f etc/nginx/sites-available/openbc /etc/nginx/sites-available
	cp -f etc/solr/*.xml $(SOLR_DIR)
	cp -f etc/tomcat6/server.xml $(TOMCAT_DIR)
	cp -R etc/service $(INSTALL_DIR)/etc/
	cp -f etc/production.psgi $(INSTALL_DIR)/app.psgi
	cp -f *.yml $(INSTALL_DIR)
	if [ ! -d /etc/service/openbc ]; then \
	    update-service --add $(INSTALL_DIR)/etc/service/openbc openbc; \
	fi
	svc -h $(INSTALL_DIR)/etc/service/openbc
	ln -sf /etc/nginx/sites-available/openbc /etc/nginx/sites-enabled/openbc
	/etc/init.d/nginx reload

copy:
	rm -rf $(INSTALL_DIR)/root
	mkdir $(INSTALL_DIR)/root
	cp -R $(STATIC_FILES) $(INSTALL_DIR)/root
