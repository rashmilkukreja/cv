# Runtime image for the static CV website.
FROM ubuntu:latest

# Keep apt non-interactive in CI/CD builds and pin the container timezone.
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Dubai

# Install Apache only; the website is static HTML/CSS/JS.
RUN apt-get update && \
    apt-get install -y apache2 && \
    apt-get clean

# Enable Apache status module so apache-exporter can collect metrics.
RUN a2enmod status

# Configure server-status endpoint for the Prometheus exporter sidecar.
RUN echo "\
<Location /server-status>\n\
    SetHandler server-status\n\
    Require all granted\n\
</Location>\n\
ExtendedStatus On\n\
" > /etc/apache2/conf-available/status.conf && \
    a2enconf status

# Copy the static CV site into Apache's default document root.
COPY . /var/www/html/

# Apache listens on port 80 inside the container and Kubernetes Service maps to it.
EXPOSE 80

# Run Apache in the foreground so the container stays alive.
CMD ["apache2ctl", "-D", "FOREGROUND"]
