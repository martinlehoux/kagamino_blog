#!/bin/sh
sudo rsync -avz --delete kagamino_blog/ /var/www/kagamino_blog/
sudo chown -R www-data:www-data /var/www/kagamino_blog
