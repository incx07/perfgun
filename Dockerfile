FROM ubuntu:16.04

#Install Open JDK 8

RUN apt-get update \
    && apt-get -y install openjdk-8-jdk software-properties-common \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
ENV PATH $JAVA_HOME/bin:$PATH

WORKDIR /opt
ENV GATLING_VERSION 2.3.1
ENV lg_name perfgun
ENV lg_id 1
ARG UNAME=carrier
ARG UID=1001
ARG GID=1001

RUN mkdir -p gatling

COPY rp_client_3.2.zip /tmp

# Install utilities
RUN add-apt-repository ppa:jonathonf/python-3.6 && apt-get update && \
    apt-get install -y --no-install-recommends bash sudo unzip git wget python3.6 python3.6-dev && \
    wget https://bootstrap.pypa.io/get-pip.py && python3.6 get-pip.py && \
    ln -s /usr/bin/python3.6 /usr/local/bin/python3 && \
    ln -s /usr/bin/python3.6 /usr/local/bin/python && \
    python -m pip install --upgrade pip && \
    apt-get clean && \
    python -m pip install setuptools==40.6.2 && \
    python -m pip install /tmp/rp_client_3.2.zip 'common==0.1.2' 'configobj==5.0.6' 'numpy==1.16.0' 'PyYAML==3.13' \
    'jira==2.0.0' 'influxdb==5.2.0' 'argparse==1.4.0' 'requests==2.19.1' 'python-logging-loki==0.1.0' && \
    rm -rf /tmp/*

# Creating carrier user and making him sudoer
RUN groupadd -g $GID $UNAME
RUN useradd -m -u $UID -g $GID -s /bin/bash $UNAME
RUN echo "carrier    ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Installing Java Jolokia
RUN  mkdir /opt/java && cd /opt/java \
 && wget -O jolokia-jvm-1.6.0-agent.jar \
 http://search.maven.org/remotecontent?filepath=org/jolokia/jolokia-jvm/1.6.0/jolokia-jvm-1.6.0-agent.jar

# Installing Telegraf
RUN cd /tmp && wget https://dl.influxdata.com/telegraf/releases/telegraf_1.8.3-1_amd64.deb && \
    dpkg -i telegraf_1.8.3-1_amd64.deb
COPY telegraf.conf /etc/telegraf/telegraf.conf
COPY jolokia.conf /opt

ENV PATH /opt/gatling/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

RUN chown -R ${UNAME}:${UNAME} /opt/gatling
RUN chown -R ${UNAME}:${UNAME} /opt/gatling/

# Installting Gatling

USER ${UNAME}

WORKDIR /opt/gatling
ENV GATLING_HOME /opt/gatling

RUN wget -q -O /tmp/gatling-$GATLING_VERSION.zip https://repo1.maven.org/maven2/io/gatling/highcharts/gatling-charts-highcharts-bundle/$GATLING_VERSION/gatling-charts-highcharts-bundle-$GATLING_VERSION-bundle.zip && \
  unzip /tmp/gatling-$GATLING_VERSION.zip && \
  mv gatling-charts-highcharts-bundle-$GATLING_VERSION/* /opt/gatling/ && \
  rm -rf gatling-charts-highcharts-bundle-$GATLING_VERSION


COPY executor.sh /opt/gatling/bin
RUN sudo chmod +x /opt/gatling/bin/executor.sh
COPY logparser.py /opt/gatling/bin
COPY compare_build_metrix.py /opt/gatling/bin
COPY config.yaml /tmp/

VOLUME ["/opt/gatling/conf", "/opt/gatling/results", "/opt/gatling/user-files"]

COPY tests /opt/gatling
COPY logback.xml /opt/gatling/conf

RUN ["/bin/bash", "-c", "/opt/gatling/bin/gatling.sh -s carrier.WarmUp"]
RUN rm -rf /opt/gatling/results/*

ENTRYPOINT ["/opt/gatling/bin/executor.sh"]