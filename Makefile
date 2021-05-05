PLATFORMS := ubuntu-2004
SLS_BINARY ?= ./node_modules/serverless/bin/serverless.js

deps:
	npm install

docker-build:
	@cd builder && docker-compose build --parallel

AWS_ACCOUNT_ID:=$(shell aws sts get-caller-identity --output text --query 'Account')
AWS_REGION := us-east-1
docker-push: ecr-login docker-build
	@for platform in $(PLATFORMS) ; do \
		docker tag python-builds:$$platform $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/python-builds:$$platform; \
		docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/python-builds:$$platform; \
	done

docker-down:
	@cd builder && docker-compose down

docker-build-python: docker-build
	@cd builder && docker-compose up

docker-shell-python-env:
	@cd builder && docker-compose run --entrypoint /bin/bash ubuntu-2004

ecr-login:
	(aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com)

rebuild-all: deps
	$(SLS_BINARY) invoke stepf -n pythonBuilds -d '{"force": true}'

serverless-deploy.%: deps
	$(SLS_BINARY) deploy --stage $*

# Helper for launching a bash session on a docker image of your choice. Defaults
# to "ubuntu:focal".
TARGET_IMAGE?=ubuntu:focal
bash:
	docker run --privileged=true -it --rm \
		-v $(CURDIR):/python-builds \
		-w /python-builds \
		${TARGET_IMAGE} /bin/bash

.PHONY: deps docker-build docker-push docker-down docker-build-python docker-shell-python-env ecr-login fetch-serverless-custom-file serverless-deploy
