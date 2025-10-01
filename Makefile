deploy:
	hugo
	rsync -avz --delete public/ ubuntu@nextcloud.kagamino.dev:~/kagamino_blog/
	rsync -avz deploy.sh ubuntu@nextcloud.kagamino.dev:~/deploy.sh
	ssh ubuntu@nextcloud.kagamino.dev 'sudo bash deploy.sh'
