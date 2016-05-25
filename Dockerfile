FROM ruby:2.3.1-alpine

MAINTAINER Jake Wilkins <jake@tolerable.tech>

ADD . /app

ENV RACK_ENV production

EXPOSE 4001

WORKDIR /app

RUN /usr/local/bin/bundle install --without development test

CMD ["/usr/local/bin/bundle", "exec", "rackup", "--port", "4001", "config.ru"]

