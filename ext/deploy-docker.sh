#!/bin/sh

if [ "$#" != 1 ]; then
    echo 'Usage: <container>' >&2
    exit 1
fi

container="$1"

# copy the extension source in the container
docker exec -u root -i "$container" rm -fr /tmp/fracker
docker cp "$(dirname "$0")" "$container:/tmp/fracker"

# run the setup script
docker exec -u root -i "$container" sh <<EOF
# install dependencies
apt-get update
apt-get install --yes autoconf gcc make pkg-config git libjson-c-dev net-tools
apt-get install --yes php-dev
apt-get install --yes php7.0-dev

# compile and install
cd /tmp/fracker
make distclean
phpize --clean
phpize
./configure
make -j "$(nproc)" all
make install

# gather host address
if [ "$(uname)" = Linux ]; then
   host="\$(route -n | awk '/UG/ { print \$2 }')"
else
   host='host.docker.internal'
fi

# set up the extension
echo "
zend_extension=xdebug.so
xdebug.trace_fracker_host=\$host
xdebug.trace_fracker_port=${PORT:-6666}
" >/tmp/fracker.ini
find / -path */php*/conf.d -exec cp /tmp/fracker.ini {} \; 2>/dev/null

# make the web server reload the configuration
pkill -x -HUP apache2
pkill -x -HUP httpd

# exit nicely
true
EOF