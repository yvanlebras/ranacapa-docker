FROM rocker/shiny:latest

# Installing dependencies needed

RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup && \
    echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache && \
    apt-get -qq update && apt-get install --no-install-recommends -y libgdal-dev libproj-dev net-tools procps libcurl4-openssl-dev libxml2-dev libssl-dev openjdk-8-jdk libgeos-dev texlive-xetex  texlive-fonts-recommended texlive-latex-recommended lmodern python-pip python-dev && \

    # Installing Galaxy bioblend dependencies to interact with Galaxy
    pip install --upgrade pip==9.0.3 && \
    pip install -U setuptools && \
    pip install bioblend galaxy-ie-helpers && \

    # Installing R package dedicated to the shniy app
    Rscript -e "install.packages('ggplot2')" && \
    Rscript -e "install.packages('reshape2')" && \
    Rscript -e "install.packages('vegan')" && \
    Rscript -e "install.packages('dplyr')" && \
    Rscript -e "install.packages('phyloseq')" && \
    Rscript -e "install.packages('broom')" && \
    Rscript -e "install.packages('plotly')" && \
    Rscript -e "install.packages('tibble')" && \
    Rscript -e "install.packages('scales')" && \
    Rscript -e "install.packages('heatmaply')" && \
    Rscript -e "install.packages('markdown')" && \
    Rscript -e "install.packages('rPython')" && \
"install_github('gauravsk/ranacapa')" && \
    # Dir for Shiny apps installation
    mkdir /srv/shiny-server/sample-apps/ranacapa


RUN apt-get install -y git-all



# Adapt download function to export to history Galaxy
COPY ./shiny-server.conf /etc/shiny-server/shiny-server.conf

# Add Galaxy related pieces of code
COPY ./ui.R /srv/shiny-server/sample-apps/ranacapa/inst/explore-anacapa-output/ui.R
COPY ./server.R /srv/shiny-server/sample-apps/ranacapa/inst/explore-anacapa-output/server.R



# Bash script to launch all processes needed
COPY shiny-server.sh /usr/bin/shiny-server.sh
RUN chmod 777 /usr/bin/shiny-server.sh
# Python script to export data to history Galaxy
COPY ./export.py /opt/python/galaxy-export/export.py


# TEMP python import, dirty for the moment
COPY ./__init__.py /usr/local/lib/python2.7/dist-packages/galaxy_ie_helpers/__init__.py
COPY ./import_list_history.py /import_list_history.py
COPY ./import_csv_user.py /import_csv_user.py


RUN apt-get install -y vim
CMD ["/usr/bin/shiny-server.sh"]
