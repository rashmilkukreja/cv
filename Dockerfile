FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Dubai

RUN apt-get update && \
    apt-get install -y apache2 && \
    apt-get clean

# Enable status module
RUN a2enmod status

# Configure server-status endpoint
RUN echo "\
<Location /server-status>\n\
    SetHandler server-status\n\
    Require all granted\n\
</Location>\n\
ExtendedStatus On\n\
" > /etc/apache2/conf-available/status.conf && \
    a2enconf status

# Copy app files
COPY . /var/www/html/

EXPOSE 80

CMD ["apache2ctl", "-D", "FOREGROUND"]