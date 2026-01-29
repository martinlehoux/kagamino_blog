build:
	rm -rf public/
	hugo

deploy: build
	rsync --rsync-path="sudo rsync" -avz --delete public/ ubuntu@feed.kagamino.dev:/var/www/kagamino_blog/

dev:
	hugo server -D

preprod:
	rm -rf public/
	hugo -D -b http://localhost:8000/
	python -m http.server -d public/
