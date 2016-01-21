# The Basics
FROM ubuntu:trusty

# Create the ergatis user
RUN /usr/sbin/groupadd ergatis
RUN /usr/sbin/useradd -g ergatis --shell /bin/bash ergatis

RUN apt-get update && \
    apt-get install -y software-properties-common git dh-make \
    build-essential devscripts openjdk-6-jre ant apache2

# Install Workflow

# Install Virome Pipeline

# Install ergatis and dependencies

# Manually set up the apache environment variables
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid

EXPOSE 80

# Update the default apache site with the config we created.
#ADD apache-config.conf /etc/apache2/sites-enabled/000-default.conf

# By default, simply start apache.
CMD /usr/sbin/apache2ctl -D FOREGROUND
