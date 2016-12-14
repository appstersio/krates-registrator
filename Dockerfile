FROM alpine:3.4
MAINTAINER Kontena, Inc. <info@kontena.io>

RUN apk update && apk --update add ruby \
  openssl ca-certificates \
  ruby-io-console ruby-json
RUN apk --update add --virtual build-dependencies ruby-dev build-base openssl-dev \
  && gem install bundler --no-ri --no-rdoc

ADD vendor/kontena/ /app/vendor/kontena/
ADD Gemfile Gemfile.lock *.gemspec /app/

WORKDIR /app

RUN bundle install --without development test

ADD . /app

CMD ["bundle", "exec", "bin/kontena-registrator"]
