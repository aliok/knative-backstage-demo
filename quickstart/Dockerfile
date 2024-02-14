FROM --platform=linux/amd64 alpine:3.18

WORKDIR /usr/src/app

RUN apk add --update \
    bash \
    curl \
    nodejs \
    npm \
    && rm -rf /var/cache/apk/*

RUN node --version
RUN npm --version

RUN npm install -g yarn
RUN yarn --version

# Download kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin/kubectl

RUN kubectl version --client

COPY ./100-manifest ./100-manifest
COPY ./backstage ./backstage

COPY ./quickstart/start-container.sh ./start-container.sh
RUN chmod +x ./start-container.sh

CMD ["./start-container.sh"]
