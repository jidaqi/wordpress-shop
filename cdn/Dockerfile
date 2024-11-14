FROM node:18 as builder

WORKDIR /app

COPY yarn.* package*.json /app/script/

RUN cd /app/script/ && npm install

COPY . /app/script/
