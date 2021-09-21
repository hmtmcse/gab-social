# Install in CentOS 8

dnf update -y
dnf install -y bind-utils wget vim net-tools traceroute
dnf config-manager --set-enabled powertools
dnf install -y epel-release
dnf install -y curl git gpg gcc git-core zlib zlib-devel gcc-c++ patch readline readline-devel libffi-devel openssl-devel make autoconf automake libtool bison curl sqlite-devel ImageMagick libxml2-devel libxslt-devel gdbm-devel ncurses-devel glibc-headers glibc-devel libicu-devel protobuf
dnf install -y libyaml-devel libidn-devel protobuf-devel

## FFMpeg
dnf localinstall -y --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm
dnf install -y --nogpgcheck https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm
dnf install -y ffmpeg ffmpeg-devel


dnf install -y bzip2

dnf install -y redis
systemctl enable --now redis

dnf module install -y nodejs:12
npm install --global yarn forever


dnf module list postgresql
dnf module -y reset postgresql
dnf module -y enable postgresql:12
dnf install -y postgresql-server postgresql-contrib postgresql-server-devel
postgresql-setup --initdb
systemctl enable --now postgresql


adduser gabsocial

#### rbenv, Ruby, Rails, Rake
curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import -
\curl -sSL https://get.rvm.io | bash -s stable
usermod -a -G rvm root
source /etc/profile.d/rvm.sh
rvm install 2.6.1


## Install app
su - gabsocial
cd /home/gabsocial/
git clone https://github.com/hmtmcse/gab-social.git
cd gab-social
gem install bundler
rm -rf Gemfile.lock
bundle install
yarn install --pure-lockfile
sudo -u postgres createuser -U postgres gabsocial -s

bundle exec rails db:setup


# Add mongo_fdw extension
dnf install -y cmake redhat-rpm-config
cd /root
git clone https://github.com/EnterpriseDB/mongo_fdw --recursive
cd mongo_fdw/
./autogen.sh --with-master
export PATH=/usr/bin/:$PATH

# Service Files
```
[Unit]
Description=gabsocial-web
After=network.target

[Service]
Type=simple
User=gabsocial
WorkingDirectory=/home/gabsocial/gab-social
Environment="RAILS_ENV=production"
Environment="PORT=3000"
ExecStart=/usr/local/rvm/gems/ruby-2.6.5/bin/bundle exec puma -C config/puma.rb
ExecReload=/bin/kill -SIGUSR1 $MAINPID
TimeoutSec=15
Restart=always

[Install]
WantedBy=multi-user.target
```

```
[Unit]
Description=gabsocial-sidekiq
After=network.target

[Service]
Type=simple
User=gabsocial
WorkingDirectory=/home/gabsocial/gab-social
Environment="RAILS_ENV=production"
Environment="DB_POOL=5"
ExecStart=/usr/local/rvm/gems/ruby-2.6.5/bin/bundle exec sidekiq -c 5 -q default -q push -q mailers -q pull
TimeoutSec=15
Restart=always

[Install]
WantedBy=multi-user.target
```


```
[Unit]
Description=gabsocial-streaming
After=network.target

[Service]
Type=simple
User=gabsocial
WorkingDirectory=/home/gabsocial/gab-social
Environment="NODE_ENV=production"
Environment="PORT=4000"
ExecStart=/usr/bin/npm run start
TimeoutSec=15
Restart=always

[Install]
WantedBy=multi-user.target
```


# Nignx cirtbot
dnf install -y epel-release
dnf install -y certbot nginx
dnf install -y python3-certbot-nginx

certbot --nginx -d sm.problemfighter.net


export RAILS_ENV=production
RAILS_ENV=production bundle exec rake gabsocial:setup

export NODE_ENV=production


sudo -u postgres psql
DROP DATABASE gabsocial_production



