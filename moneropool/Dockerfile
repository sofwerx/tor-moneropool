From ubuntu:16.04

RUN apt-get update && apt-get install -y git python-dev python-pip build-essential make libboost-all-dev npm
RUN git clone https://github.com/Kukunin/node-cryptonote-pool /app

WORKDIR /app

RUN npm install --loglevel info

ADD run.sh /run.sh

CMD /run.sh
