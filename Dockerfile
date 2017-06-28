FROM debian:stretch

ENV USER=rstudio

ARG PANDOC_TEMPLATES_VERSION
ARG BUILD_DATE
ENV PANDOC_TEMPLATES_VERSION ${PANDOC_TEMPLATES_VERSION:-1.18}
ENV TERM=xterm \
    DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/lib/rstudio-server/bin:$PATH

# Set locale
RUN apt-get update \
  && apt-get install -y --no-install-recommends locales \
  && echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen \
  && locale-gen en_GB.utf8 \
  && /usr/sbin/update-locale LANG=en_GB.UTF-8 \
  && rm -rf /var/lib/apt/lists/*
ENV LC_ALL=en_GB.UTF-8 \
    LANG=en_GB.UTF-8

# Install R Dependencies
RUN apt-get update \
  && apt-get install -y software-properties-common apt-transport-https gnupg \
  && add-apt-repository 'deb https://cran.ma.imperial.ac.uk/bin/linux/debian stretch-cran34/' \
  && apt-key adv --recv-key 'E19F5F87128899B192B1A2C2AD5F960A256A04AF' \
  && apt-get update \
  && apt-get install -y \
    r-base \
    r-base-dev \
    r-recommended \
    libopenblas-base \
    curl \
    wget

  ## Add a default CRAN mirror
RUN echo "options(repos = c(CRAN = 'https://cran.rstudio.com/'), download.file.method = 'libcurl')" >> /etc/R/Rprofile.site \
  ## Add a library directory (for user-installed packages)
  && mkdir -p /usr/local/lib/R/site-library \
  && chown root:staff /usr/local/lib/R/site-library \
  && chmod g+wx /usr/local/lib/R/site-library \
  ## Fix library path
  && echo "R_LIBS_USER='/usr/local/lib/R/site-library'" >> /etc/R/Renviron \
  && echo "R_LIBS=\${R_LIBS-'/usr/local/lib/R/site-library:/usr/local/lib/R/library:/usr/lib/R/library'}" >> /etc/R/Renviron \
  ## install packages from date-locked MRAN snapshot of CRAN
  && [ -z "$BUILD_DATE" ] && BUILD_DATE=$(TZ="America/Los_Angeles" date -I) || true \
  && MRAN=https://mran.microsoft.com/snapshot/${BUILD_DATE} \
  && echo MRAN=$MRAN >> /etc/environment \
  && export MRAN=$MRAN \
  ## MRAN becomes default only in versioned images
  ## Use littler installation scripts
  && Rscript -e "install.packages(c('littler', 'docopt'), repo = '$MRAN')" \
  && ln -s /usr/local/lib/R/site-library/littler/examples/install2.r /usr/local/bin/install2.r \
  && ln -s /usr/local/lib/R/site-library/littler/examples/installGithub.r /usr/local/bin/installGithub.r \
  && ln -s /usr/local/lib/R/site-library/littler/bin/r /usr/local/bin/r \
  ## TEMPORARY WORKAROUND to get more robust error handling for install2.r prior to littler update
  && curl -O /usr/local/bin/install2.r https://github.com/eddelbuettel/littler/raw/master/inst/examples/install2.r \
  && chmod +x /usr/local/bin/install2.r \
  && rm -rf /var/lib/apt/lists/*

## Download and install RStudio server & dependencies
## Attempts to get detect latest version, otherwise falls back to version given in $VER
## Symlink pandoc, pandoc-citeproc so they are available system-wide
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    git \
    libapparmor1 \
    libcurl4-openssl-dev \
    libedit2 \
    libssl-dev \
    lsb-release \
    psmisc \
    python-setuptools \
    sudo \
    rrdtool \
    openssh-client \
    libxml2-dev \
    texinfo \
    texlive \
    texlive-latex-extra \
    default-jre \
    default-jdk \
    bzip2 \
    libbz2-dev \
    libpcre3-dev \
    liblzma-dev \
    libicu-dev \
    libpng-dev \
    libjpeg-dev \
    libpoppler-cpp-dev \
    libgeos-dev \
    libgdal-dev \
    libproj-dev \
  && rm -rf /var/lib/apt/lists/* \
  && wget -O libssl1.0.0.deb http://ftp.debian.org/debian/pool/main/o/openssl/libssl1.0.0_1.0.1t-1+deb8u6_amd64.deb \
  && dpkg -i libssl1.0.0.deb \
  && rm libssl1.0.0.deb

# Install RStudio
RUN wget -q https://download2.rstudio.org/rstudio-server-pro-1.0.143-amd64.deb \
  && dpkg -i rstudio-server-pro-1.0.143-amd64.deb \
  && rm rstudio-server-pro-*-amd64.deb \

  # Configure RStudio
  && echo '\n\
  \nserver-access-log=1 \
  \nserver-project-sharing=0 \
  \nserver-health-check-enabled=1 \
  \n' >> /etc/rstudio/rserver.conf \

  # Install pandoc
  && ln -s /usr/lib/rstudio-server/bin/pandoc/pandoc /usr/local/bin \
  && ln -s /usr/lib/rstudio-server/bin/pandoc/pandoc-citeproc /usr/local/bin \
  && wget https://github.com/jgm/pandoc-templates/archive/${PANDOC_TEMPLATES_VERSION}.tar.gz \
  && mkdir -p /opt/pandoc/templates && tar zxf ${PANDOC_TEMPLATES_VERSION}.tar.gz \
  && cp -r pandoc-templates*/* /opt/pandoc/templates && rm -rf pandoc-templates* \
  && mkdir /root/.pandoc && ln -s /opt/pandoc/templates /root/.pandoc/templates \

  ## Configure R
  && mkdir -p /etc/R \
  && echo '\n\
    \n .libPaths("~/R/library") \
    \n# Configure httr to perform out-of-band authentication if HTTR_LOCALHOST \
    \n# is not set since a redirect to localhost may not work depending upon \
    \n# where this Docker container is running. \
    \nif(is.na(Sys.getenv("HTTR_LOCALHOST", unset=NA))) { \
    \n  options(httr_oob_default = TRUE) \
    \n}' >> /etc/R/Rprofile.site \
  && echo "PATH=\"${PATH}\"" >> /etc/R/Renviron \
  && echo "r-libs-user=~/R/library" >> /etc/rstudio/rsession.conf \

  ## Configure RStudio profile
  && echo '\n\
  \n[*] \
  \nmax-memory-mb = 12288 \
  \n' >> /etc/rstudio/profiles

# Install R Packages
RUN R -e "install.packages(c(\
    'Rcpp', \
    'aws.s3', \
    'aws.signature', \
    'base64enc', \
    'base64enc', \
    'bitops', \
    'caTools', \
    'codetools', \
    'curl', \
    'devtools', \
    'digest', \
    'digest', \
    'evaluate', \
    'formatR', \
    'highr', \
    'htmltools', \
    'httr', \
    'jsonlite', \
    'knitr', \
    'markdown', \
    'readr', \
    'rmarkdown', \
    'rprojroot', \
    'shiny', \
    'stringr', \
    'tidyverse', \
    'xml2', \
    'yaml' \
    ))" \

  # Install R S3 package
  && R -e "install.packages(c('aws.signature', 'aws.s3'), \
    repos = c('cloudyr' = 'http://cloudyr.github.io/drat'))" \

  # Install MOJ S3tools package
  && R -e "devtools::install_github('moj-analytical-services/s3tools')" \

  # Install webshot/phantomjs for Doc/PDF with JS graphs in it
  && R -e "install.packages('webshot')" \
  && R -e "webshot::install_phantomjs()" \
  && mv /root/bin/phantomjs /usr/bin/phantomjs \
  && chmod a+rx /usr/bin/phantomjs

# Configure git
RUN git config --system credential.helper 'cache --timeout=3600' \
  && git config --system push.default simple

RUN echo "rstudio:rstudio" | chpasswd

COPY start.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 8787

CMD ["/usr/local/bin/start.sh"]
