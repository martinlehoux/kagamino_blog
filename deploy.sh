#!/bin/sh
sudo mv kagamino_blog.conf /etc/apache2/sites-available/
sudo ln -fs /etc/apache2/sites-available/kagamino_blog.conf /etc/apache2/sites-enabled/
sudo rsync -avz --delete kagamino_blog/ /var/www/kagamino_blog/
sudo chown -R www-data:www-data /var/www/kagamino_blog
sudo service apache2 restart