./configure --add-module=/home/chandler/stream --with-stream --with-lua51 --with-pcre=/usr/local/pcre

./configure --with-stream --with-pcre=/data/chandler/pcre-8.38 --with-openssl=/data/chandler/openssl-1.0.1e --with-luajit=/data/app/nginx/luajit --add-module=/data/chandler/stream --error-log-path=log/error.log  --http-log-path=log/access.log --pid-path=log/nginx.pid --lock-path=log/nginx.lock



./configure --with-stream --with-pcre=/data/chandler/pcre-8.38 --with-openssl=/data/chandler/openssl-1.0.1e --with-luajit=/data/app/nginx/luajit --add-module=/data/chandler/nb_openresty/bundle/stream-lua-nginx-module-0.0.1/ --error-log-path=log/error.log  --http-log-path=log/access.log --pid-path=log/nginx.pid --lock-path=log/nginx.lock