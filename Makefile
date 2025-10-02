deploy:
	hugo
	rsync -avz --delete public/ ubuntu@feed.kagamino.dev:~/kagamino_blog/
	rsync -avz deploy.sh ubuntu@feed.kagamino.dev:~/deploy.sh
	ssh ubuntu@feed.kagamino.dev 'sudo bash deploy.sh'

dev:
	hugo server -D

build:
	hugo -D -b http://localhost:8000/
	python -m http.server -d public/
