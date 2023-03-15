PROJECT_NAME=
DEPLOY_SERVER=

## check form arm64 and apply override COMPOSE_FILE
## uname -m not used because we might be running a amd64 shell even in a arm-based mac
UNAME=$(uname -v)
ifneq (,$(findstring $(UNAME),ARM64))
	COMPOSE_FILE=local.yml:local.arm.yml
else
	COMPOSE_FILE=local.yml
endif

export COMPOSE_FILE

.PHONY: help up down build force_build start stop prune clear ps run_tests cp_local_db restore_db cp_prodcution_db postgres_bash psql createdb dropdb dropdbf production_bash bash shell manage deploy
default: up

## help	:	Print commands help.
help : Makefile
	@sed -n 's/^##//p' $<

## up	:	Start up containers.
up:
	@echo "Starting up containers for $(PROJECT_NAME)..."
	# docker-compose pull
	# docker-compose build
	docker-compose up -d --remove-orphans

## down	:	Remove containers.
down:
	@echo "Removing containers for $(PROJECT_NAME)..."
	docker-compose down --remove-orphans

## build	:	Build python image.
build:
	@echo "Building python image for $(PROJECT_NAME) using $(COMPOSE_FILE)..."
	docker-compose build

## force_build	:	Build python image without using cached.
force_build:
	@echo "Building python image for $(PROJECT_NAME) using $(COMPOSE_FILE)..."
	docker-compose build --no-cache

## start	:	Start containers without updating.
start:
	@echo "Starting containers for $(PROJECT_NAME) from where you left off..."
	docker-compose start

## stop	:	Stop containers.
stop:
	@echo "Stopping containers for $(PROJECT_NAME)..."
	docker-compose stop

## prune	:	Remove containers and their volumes.
##		You can optionally pass an argument with the service name to prune single container
##		prune postgres	: Prune `mariadb` container and remove its volumes.
##		prune postgres redis	: Prune `postgres` and `redis` containers and remove their volumes.
prune:
	@echo "Removing containers for $(PROJECT_NAME)..."
	docker-compose down -v --remove-orphans --rmi all $(filter-out rm,$(filter-out $@,$(MAKECMDGOALS)))

## clear       :	Remove images, containers and their volumes. Also prunes docker
##		Use with caution
clear: prune
	@echo "Removing images for $(PROJECT_NAME)..."
	$(eval IMAGES=$(shell docker images -f 'reference=$(PROJECT_NAME)*' -q))
	@if [ -n "$(IMAGES)" ]; then docker rmi $(IMAGES); docker image prune -af; docker builder prune -af; fi

## ps	:	List running containers.
ps:
	docker ps --filter name='$(PROJECT_NAME)*'

## run_tests : run django pytest
run_tests: up
	docker-compose run django pytest


# This hack allows for exec when an existing container is found, instead of run --rm
CONTAINER=django
RUN=exec
ENTRYPOINT='/entrypoint'
EXEC=$(shell COMPOSE_FILE=$(COMPOSE_FILE) docker-compose $(RUN) $(CONTAINER) ls > /dev/null 2>&1; echo $$?)

ifeq ($(EXEC), 0)
	RUN=exec
	ENTRYPOINT='/entrypoint'
else
	RUN=run --rm
	ENTRYPOINT=
endif


## load_fixtures	:	Loading all fixtures
load_fixtures:
	@echo "Loading all fixtures"
	for fixture in $$(find . -iname fixtures); do \
		docker-compose $(RUN) $(CONTAINER) $(ENTRYPOINT) python manage.py loaddata $$fixture/*; \
	done

## cp_local_db	:	copy database backup
##		Example: make cp_backup xxx.sql.gz
##		Use with caution, not enough tests made yet
cp_local_db:
	$(eval DB_IMAGE_ID=$(shell docker ps --filter name='$(PROJECT_NAME).*postgres' --format "{{.ID}}"))
	docker-compose exec $(DB_IMAGE_ID) backup
	docker cp $(DB_IMAGE_ID):/backups/$(filter-out $@,$(MAKECMDGOALS)) .

## restore_db	:	Restore database backup needs a database dump
##		Example: make restore_db xxx.sql.gz
##		$(notdir ...) introduced to allow for backups in subdirectories
##		Use with caution, not enough tests made yet
restore_db:
	$(eval DB_IMAGE_ID=$(shell docker ps --filter name='$(PROJECT_NAME).*postgres' --format "{{.ID}}"))
	docker cp $(filter-out $@,$(MAKECMDGOALS)) $(DB_IMAGE_ID):/backups
	docker-compose exec postgres restore $(notdir $(filter-out $@,$(MAKECMDGOALS)))

## cp_production_db	 :	Get latest db production dump to backups folder
cp_production_db:
	mkdir -p backups
	rsync -azrP django@$(DEPLOY_SERVER):/var/lib/autopostgresqlbackup/latest/$(PROJECT_NAME)_* backups/

## postgres_bash : Access `postgres` container via shell.
## alias for bash postgres
postgres_bash:
	$(eval DB_IMAGE_ID=$(shell docker ps --filter name='$(PROJECT_NAME).*postgres' --format "{{.ID}}"))
	docker exec -it $(DB_IMAGE_ID) /bin/bash

## psql :   Access postgres client on the default database.
##     make psql
psql:
	$(eval DB_IMAGE_ID=$(shell docker ps --filter name='$(PROJECT_NAME).*postgres' --format "{{.ID}}"))
	$(eval POSTGRES_USER=$(shell docker exec $(DB_IMAGE_ID) env | grep POSTGRES_USER | cut -d'=' -f2))
	$(eval POSTGRES_DB=$(shell docker exec $(DB_IMAGE_ID) env | grep POSTGRES_DB | cut -d'=' -f2))
	docker exec -it $(DB_IMAGE_ID) psql -U $(POSTGRES_USER) $(POSTGRES_DB)

## createdb :   Creates db on Postgres container.
##     make createdb
##     Creates a database with the default name set on envs.
createdb:
	$(eval DB_IMAGE_ID=$(shell docker ps --filter name='$(PROJECT_NAME).*postgres' --format "{{.ID}}"))
	$(eval POSTGRES_USER=$(shell docker exec $(DB_IMAGE_ID) env | grep POSTGRES_USER | cut -d'=' -f2))
	$(eval POSTGRES_DB=$(shell docker exec $(DB_IMAGE_ID) env | grep POSTGRES_DB | cut -d'=' -f2))
	docker exec -it $(DB_IMAGE_ID) createdb -U $(POSTGRES_USER) --owner=$(POSTGRES_USER) $(POSTGRES_DB)

## dropdb :  Drop db on Postgres container.
##     make dropdb
##     Drops the database with the default name on envs.
dropdb:
	$(eval DB_IMAGE_ID=$(shell docker ps --filter name='$(PROJECT_NAME).*postgres' --format "{{.ID}}"))
	$(eval POSTGRES_USER=$(shell docker exec $(DB_IMAGE_ID) env | grep POSTGRES_USER | cut -d'=' -f2))
	$(eval POSTGRES_DB=$(shell docker exec $(DB_IMAGE_ID) env | grep POSTGRES_DB | cut -d'=' -f2))
	docker exec -it $(DB_IMAGE_ID) dropdb -U $(POSTGRES_USER) $(POSTGRES_DB)

## dropdbf : Forces Drop db even if connections are active on Postgres container.
##     make dropdbf
##     Drops the database with the default name on envs.
dropdbf:
	$(eval DB_IMAGE_ID=$(shell docker ps --filter name='$(PROJECT_NAME).*postgres' --format "{{.ID}}"))
	$(eval POSTGRES_USER=$(shell docker exec $(DB_IMAGE_ID) env | grep POSTGRES_USER | cut -d'=' -f2))
	$(eval POSTGRES_DB=$(shell docker exec $(DB_IMAGE_ID) env | grep POSTGRES_DB | cut -d'=' -f2))
	docker exec -it $(DB_IMAGE_ID) psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$(POSTGRES_DB)' AND pid <> pg_backend_pid();"
	docker exec -it $(DB_IMAGE_ID) dropdb -U $(POSTGRES_USER) $(POSTGRES_DB)

## production bash	:	Access deploy server via ssh.
production_bash:
	ssh -v django@$(DEPLOY_SERVER)

## bash	:	Access container via shell.
##		You can optionally pass an argument with a service name to open a shell on the specified container
bash:
	docker-compose $(RUN) $(CONTAINER) $(ENTRYPOINT) bash $(filter-out $@,$(MAKECMDGOALS))


## shell	:	Access `django/python shell` container via shell.
##		You can optionally pass an argument with a service name to open a shell on the specified container
shell:
	docker-compose $(RUN) $(CONTAINER) $(ENTRYPOINT) python manage.py shell $(filter-out $@,$(MAKECMDGOALS))

## manage	:   django manage command
##		You can optionally pass an argument to manage
##		To use "--flag" arguments include them in quotation marks.
##		For example: make manage "makemessages --locale=pt"
manage:
	docker-compose $(RUN) $(CONTAINER) $(ENTRYPOINT) python manage.py $(filter-out $@,$(MAKECMDGOALS)) $(subst \,,$(MAKEFLAGS))

deploy:
	ssh django@$(DEPLOY_SERVER) " \
      cd /home/django/django \
      && source /home/django/.virtualenvs/django/bin/activate \
      && git pull \
      && git checkout main \
      && pip install -r requirements/production.txt \
      && python manage.py migrate \
      && python manage.py collectstatic --no-input \
      && sudo supervisorctl restart django \
      && exit"


# https://stackoverflow.com/a/6273809/1826109
%:
	@:
