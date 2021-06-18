FROM rocker/tidyverse:4.0.3
LABEL maintainer="Mark Wheldon <biostatmark@gmail.com>"



###### BELOW: based on 'https://github.com/andrewheiss/tidyverse-stan/blob/master/3.5.1/Dockerfile'

# Install ed, since nloptr needs it to compile
# Install clang and ccache to speed up Stan installation
# Install libxt-dev for Cairo 
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       apt-utils \
       nano \
       curl \
       ed \
       libnlopt-dev \
       clang \
       ccache \
       libxt-dev \
       libv8-dev \
       build-essential \
       libgl1-mesa-dev libglu1-mesa-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/

# Set up environment
# Use correct Stan Makevars: https://github.com/stan-dev/rstan/wiki/Installing-RStan-on-Mac-or-Linux#prerequisite--c-toolchain-and-configuration
RUN mkdir -p $HOME/.R \
    # Add global configuration files
    # Docker chokes on memory issues when compiling with gcc, so use ccache and clang++ instead
    && echo '\n \
        \nCC=/usr/bin/ccache clang \
        \n \
        \n# Use clang++ and ccache \
        \nCXX=/usr/bin/ccache clang++ -Qunused-arguments  \
        \n \
        \n# Optimize building with clang \
        \nCXXFLAGS=-g -O3 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security -D_FORTIFY_SOURCE=2 -g -pedantic -g0 \
        \n \
        \n# Stan stuff \
        \nCXXFLAGS+=-O3 -mtune=native -march=native -Wno-unused-variable -Wno-unused-function -Wno-macro-redefined \
        \n' >> $HOME/.R/Makevars \
    # Make R use ccache correctly: http://dirk.eddelbuettel.com/blog/2017/11/27/
    && mkdir -p $HOME/.ccache/ \
    && echo "max_size = 5.0G \
        \nsloppiness = include_file_ctime \
        \nhash_dir = false \
        \n" >> $HOME/.ccache/ccache.conf \
    # Add configuration files for RStudio user
    && mkdir -p /home/rstudio/.R/ \
    && echo '\n \
        \n# Stan stuff \
        \nCXXFLAGS=-O3 -mtune=native -march=native -Wno-unused-variable -Wno-unused-function -Wno-macro-redefined \
        \n' >> /home/rstudio/.R/Makevars \
    && echo "rstan::rstan_options(auto_write = TRUE)\n" >> /home/rstudio/.Rprofile \
    && echo "options(mc.cores = parallel::detectCores())\n" >> /home/rstudio/.Rprofile

# Install Stan, rstan, rstanarm, brms, and friends

RUN install2.r --error --deps TRUE rstan loo bayesplot
RUN Rscript -e 'install.packages("cmdstanr", repos = c("https://mc-stan.org/r-packages/", getOption("repos")))'
RUN Rscript -e 'cmdstanr::install_cmdstan()'
RUN install2.r --error --deps TRUE rstanarm rstantools shinystan brms 

# Install cmdstan

RUN cd /opt \
    && git clone https://github.com/stan-dev/cmdstan.git --recursive \
    && cd cmdstan \
    && make build \
    && export PATH="/opt/cmdstan/bin:$PATH"

## DemoTools (no 'suggests'). 

RUN install2.r --error ungroup rgl
RUN Rscript -e 'remotes::install_github("josehcms/fertestr")'
RUN Rscript -e 'remotes::install_github("timriffe/DemoTools")'
RUN Rscript -e 'remotes::install_github("cimentadaj/DDSQLtools")'

## Extra packages for this project

RUN install2.r --error --deps tictoc egg

## Clean up

RUN rm -rf /tmp/downloaded_packages/ /tmp/*.rds
