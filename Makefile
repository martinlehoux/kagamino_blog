deploy:
	hugo
	rsync -avz --delete public/ ubuntu@nextcloud.kagamino.dev:~/kagamino_blog/
	rsync -avz deploy.sh ubuntu@nextcloud.kagamino.dev:~/deploy.sh
	rsync -avz apache.conf ubuntu@nextcloud.kagamino.dev:~/kagamino_blog.conf