FROM ubuntu

RUN apt-get update
RUN apt-get -y install apache2

COPY ./rashmil-cv  /var/www/html/

RUN echo '. /etc/apache2/envvars' > /root/run_apache.sh && \
echo 'mkdir -p /var/run/apache2' >> /root/run_apache.sh && \
echo '/mkdir -p /var/lock/apache2' >> /root/run_apache.sh && \
echo 'usr/sbin/apache2 -D FOREGROUND' >> /root/run_apache.sh && \
chmod 755 /root/run_apache.sh

EXPOSE 80

CMD /root/run_apache.sh
ENV TZ=Asia/Dubai