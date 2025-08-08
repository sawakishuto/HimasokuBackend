FROM ruby:3.3.7-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    libpq-dev \
    libyaml-dev \
    git \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

# Set environment variables for development
ENV RAILS_ENV=development
ENV BUNDLE_PATH=/usr/local/bundle

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install

# Copy application code
COPY . .

# Create necessary directories and set permissions
RUN mkdir -p tmp/pids log storage && \
    chmod +x bin/rails bin/rake

# Expose port
EXPOSE 3000

# Start server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
