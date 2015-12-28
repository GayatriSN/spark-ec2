#!/usr/bin/env bash

# download rstudio 

sudo apt-get install gdebi-core
wget https://download2.rstudio.org/rstudio-server-0.99.489-amd64.deb
sudo gdebi rstudio-server-0.99.489-amd64.deb

# restart rstudio 
rstudio-server restart 

# add user for rstudio, user needs to supply password later on
adduser rstudio

# create a Rscript that connects to Spark, to help starting user
cp /root/spark-ec2/rstudio/startSpark.R /home/rstudio

# make sure that the temp dirs exist and can be written to by any user
# otherwise this will create a conflict for the rstudio user
function create_temp_dirs {
  location=$1
  if [[ ! -e $location ]]; then
    mkdir -p $location
  fi
  chmod a+w $location
}

create_temp_dirs /mnt/spark
create_temp_dirs /mnt2/spark
create_temp_dirs /mnt3/spark
create_temp_dirs /mnt4/spark
