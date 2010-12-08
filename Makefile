STATIC_FILES=static/*
INSTALL_DIR=/var/www/openbc
SOLR_DIR=/etc/solr
TOMCAT_DIR=/etc/tomcat6
install: $(STATIC_FILE)
	rm -rf $(INSTALL_DIR)/root
	mkdir $(INSTALL_DIR)/root
	cp -R $(STATIC_FILES) $(INSTALL_DIR)/root
	cp -f etc/nginx/sites-available/openbc /etc/nginx/sites-available
	cp -f etc/solr/*.xml $(SOLR_DIR)
	cp -f etc/solr/conf/*.xml $(SOLR_DIR)/conf
	cp -f etc/solr/conf/xslt/* $(SOLR_DIR)/conf/xslt
	cp -f etc/tomcat6/server.xml $(TOMCAT_DIR)
	ln -sf /etc/nginx/sites-available/openbc /etc/nginx/sites-enabled/openbc
	/etc/init.d/nginx reload
