FROM ruby:3.1.1-bullseye
WORKDIR /app

COPY Gemfile Gemfile.* .
RUN bundle install

COPY . .

CMD ["bundle", "exec", "rackup"]