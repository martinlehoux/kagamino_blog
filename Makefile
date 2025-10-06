deploy:
	hugo
	rsync --rsync-path="sudo rsync" -avz --delete public/ ubuntu@feed.kagamino.dev:/var/www/kagamino_blog/

dev:
	hugo server -D

build:
	hugo -D -b http://localhost:8000/
	python -m http.server -d public/
