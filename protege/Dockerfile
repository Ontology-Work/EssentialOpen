FROM eclipse-temurin:8-jre

WORKDIR /opt

RUN apt-get update && apt-get upgrade -y

# Enable and install SSH
# ssh root@127.0.0.1 -p 2222 -c aes256-cbc
ENV SSH_PASSWD "root:Docker!"
RUN apt-get install -y --no-install-recommends dialog \
    && apt-get update \
    && apt-get install -y --no-install-recommends openssh-server \
    && echo "$SSH_PASSWD" | chpasswd 

COPY sshd_config /etc/ssh/

RUN apt-get install -y vim netcat-traditional iputils-ping net-tools tcpdump

EXPOSE 5200 5100

COPY downloads/install_protege_3.5-Linux64-noJVM.bin ./
RUN chmod u+x install_protege_3.5-Linux64-noJVM.bin \
   && ./install_protege_3.5-Linux64-noJVM.bin -i console

RUN adduser --system --home /opt/Protege_3.5/ protege
RUN rm install_protege_3.5-Linux64-noJVM.bin
RUN mv /root/Protege_3.5/ /opt/
RUN chown -R protege:root /opt/Protege_3.5/

# Essential Open Source Server Configuration
COPY auto-install.xml ./
COPY downloads/essentialinstallupgrade67.jar ./
RUN java -jar essentialinstallupgrade67.jar auto-install.xml
RUN rm essentialinstallupgrade67.jar

# Meta-Model
RUN mkdir -p EssentialAM/Repository
# Protege Server
RUN mkdir -p EssentialAM/server

# JDBC Driver
COPY downloads/mysql-connector-j-8.0.33.jar /opt/Protege_3.5/driver.jar

# # Setup Environment
ENV CODEBASE_URL=file:/opt/Protege_3.5/protege.jar
ENV CATALINA_OPTS="-Xms1G -Xmx2G"

COPY run_protege.sh /opt/run_protege.sh
RUN chmod +x /opt/run_protege.sh

WORKDIR /opt/Protege_3.5/

# Startup the services
CMD ["/opt/run_protege.sh", ""]
