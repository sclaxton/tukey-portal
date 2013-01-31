#!/bin/bash

# Install tukey portal
# TODO: Write this in python and make it portable

LOCAL_SETTINGS_FILE=/home/ubuntu/site_local_settings.py

# Use the last stable Horizon commit
STABLE=true

MULTI_SITE=false

CREATE_DATABASE=false

CONFIGURE_APACHE=true
CREATE_CONSOLE=true

# Last commit of Horizon tested against
HORIZON_COMMIT=3a9b0da489030eaacc6cc0416f92192b74783ac8

# Site specific installation variables

# Where to install MUST be absolute path for linking
BASE_DIR=/var/www/tukey
HORIZON_DIR=tukey-portal
RUN_USER=ubuntu
RUN_GROUP=ubuntu

# Probably wont change
TUKEY_DIR=tukey

sudo apt-get install -y nodejs

sudo git clone https://github.com/openstack/horizon.git $BASE_DIR/$HORIZON_DIR
sudo chown -R $RUN_USER:$RUN_GROUP $BASE_DIR/$HORIZON_DIR

if $STABLE
then
    cd $BASE_DIR/$HORIZON_DIR
    echo "Using current stable Horizon commit: $HORIZON_COMMIT"
    git checkout $HORIZON_COMMIT
    cd -
else
    echo "WARNING! Using unstable latest version of Horizon"
fi

# Copy tukey subdir into Horizon 
cp -r $TUKEY_DIR $BASE_DIR/$HORIZON_DIR



# I no longer think this is the best way to do this
# instead we will have the entire local settings file in a directory
# that is site specific probably under /usr/local/etc/tukey
# so lets just link our file from there...

ln -s $LOCAL_SETTINGS_FILE $BASE_DIR/$HORIZON_DIR/openstack_dashboard/local/local_settings.py


cd $BASE_DIR/$HORIZON_DIR

# Apply patches for the stuff we couldn't monkey-patch
patch -p1 < $TUKEY_DIR/patches/horizon.patch
patch -p1 < $TUKEY_DIR/patches/openstack_dashboard.patch

# Append to 

echo "# Tukey Requirements automatically generated by install.sh 
python-openid
django-openid-auth
psycopg2
python-memcached
" >> tools/pip-requires

python tools/install_venv.py

if $CONFIGURE_APACHE
then
    # Generate Apache config file openstack-dashboard.conf
    
    echo "# Automatically generated by install.sh
    WSGIScriptAlias / $BASE_DIR/$HORIZON_DIR/openstack_dashboard/wsgi/django.wsgi
    
    WSGIDaemonProcess tukey-portal user=$RUN_USER group=$RUN_GROUP python-path=$BASE_DIR/$HORIZON_DIR:$BASE_DIR/$HORIZON_DIR/.venv/lib/python2.7/site-packages
    
    WSGIProcessGroup tukey-portal
    
    Alias /static $BASE_DIR/$HORIZON_DIR/$TUKEY_DIR/static/
    
    <Directory $BASE_DIR/$HORIZON_DIR/openstack_dashboard/wsgi>
      Order allow,deny
      Allow from all
    </Directory>
    
    <Directory $BASE_DIR/$HORIZON_DIR/$TUKEY_DIR/static>
      Order allow,deny
      Allow from all
    </Directory>" > $TUKEY_DIR/openstack-dashboard.conf 
    
    sudo ln -s $BASE_DIR/$HORIZON_DIR/$TUKEY_DIR/openstack-dashboard.conf /etc/apache2/sites-available/
    

    if $CREATE_CONSOLE
    then    
    
        echo "# Automatically generated by install.sh
        NameVirtualHost *:80
        
        
        <Virtualhost *:80>
            ServerName console.opensciencedatacloud.org
        
            ErrorLog /var/log/apache2/console-error.log
            CustomLog /var/log/apache2/console-access.log common
        
            UseCanonicalName On
        
            include /etc/apache2/sites-available/openstack-dashboard.conf
        
        </virtualhost>" > /etc/apache2/sites-available/console.conf

        sudo a2ensite console

    fi

fi

if $CREATE_DATABASE
then
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
    sudo -u postgres psql -c "CREATE USER $DB_USER with PASSWORD '$DB_PASSWORD';"
fi
