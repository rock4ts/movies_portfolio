# Для запуска в docker-compose
build:
	docker-compose build

up:
	docker-compose up -d

logs:
	docker-compose logs $(service)

down:
	docker-compose down

full-down:
	docker-compose down --volumes --remove-orphans

clear:
	docker system prune
