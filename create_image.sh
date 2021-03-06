#!/bin/bash
# Creates an AMI for the Spark EC2 scripts starting with a stock Amazon 
# Linux AMI.
# This has only been tested with Amazon Linux AMI 2014.03.2 

set -e

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Dev tools
sudo apt-get install -y build-essential gcc g++ ant
# Perf tools
sudo apt-get install -y dstat iotop strace sysstat htop 
# sudo apt-get install linux-tools

# trying to get things work without these for now
# ned to ind a workaround here
#sudo debuginfo-install -q -y glibc
#sudo debuginfo-install -q -y kernel
#sudo yum --enablerepo='*-debug*' install -q -y java-1.7.0-openjdk-debuginfo.x86_64

# PySpark and MLlib deps
sudo apt-get install -y  python-matplotlib python-tornado python-scipy gfortran-4.8

# SparkR deps
#sudo yum install -y R

# Getting R working
echo "deb http://cran.univ-paris1.fr/bin/linux/ubuntu trusty/" >> /etc/apt/sources.list
gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9
gpg -a --export E084DAB9 | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install r-base r-base-dev

# Other handy tools
sudo apt-get install -y pssh

# Ganglia
sudo apt-get install -y ganglia-monitor rrdtool gmetad ganglia-webfrontend

# Root ssh config
sudo sed -i 's/PermitRootLogin.*/PermitRootLogin without-password/g' \
  /etc/ssh/sshd_config
sudo sed -i 's/disable_root.*/disable_root: 0/g' /etc/cloud/cloud.cfg

# Set up ephemeral mounts
sudo sed -i 's/mounts.*//g' /etc/cloud/cloud.cfg
sudo sed -i 's/.*ephemeral.*//g' /etc/cloud/cloud.cfg
sudo sed -i 's/.*swap.*//g' /etc/cloud/cloud.cfg

echo "mounts:" >> /etc/cloud/cloud.cfg
echo " - [ ephemeral0, /mnt, auto, \"defaults,noatime,nodiratime\", "\
  "\"0\", \"0\" ]" >> /etc/cloud.cloud.cfg

for x in {1..23}; do
  echo " - [ ephemeral$x, /mnt$((x + 1)), auto, "\
    "\"defaults,noatime,nodiratime\", \"0\", \"0\" ]" >> /etc/cloud/cloud.cfg
done

# Install Maven (for Hadoop)
cd /tmp
wget "http://archive.apache.org/dist/maven/maven-3/3.2.3/binaries/apache-maven-3.2.3-bin.tar.gz"
tar xvzf apache-maven-3.2.3-bin.tar.gz
mv --backup=numbered apache-maven-3.2.3 /opt/

# Edit bash profile
echo "export PS1=\"\\u@\\h \\W]\\$ \"" >> ~/.profile
echo "export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64" >> ~/.profile
echo "export M2_HOME=/opt/apache-maven-3.2.3" >> ~/.profile
echo "export PATH=\$PATH:\$M2_HOME/bin" >> ~/.profile

source ~/.profile

#another temporary workaround... really running short on time now, so need to use these dirty hacks
#export PS1=\"\\u@\\h \\W]\\$ \"
export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64
export M2_HOME=/opt/apache-maven-3.2.3
#export PATH=\$PATH:\$M2_HOME/bin

# Build Hadoop to install native libs
mkdir /root/hadoop-native || true
cd /tmp
sudo apt-get install -y protobuf-compiler cmake openssl libssl-dev
wget "http://archive.apache.org/dist/hadoop/common/hadoop-2.4.1/hadoop-2.4.1-src.tar.gz"
tar xvzf hadoop-2.4.1-src.tar.gz
cd hadoop-2.4.1-src
mvn package -Pdist,native -DskipTests -Dtar || true
sudo mv hadoop-dist/target/hadoop-2.4.1/lib/native/* /root/hadoop-native || true
# ignoring build and using a binary instead
wget https://archive.apache.org/dist/hadoop/core/hadoop-2.4.1/hadoop-2.4.1.tar.gz
cp hadoop-2.4.1.tar.gz /root/hadoop-native || true
# adding these || true to re-run scripts during testing

# Install Snappy lib (for Hadoop)
sudo apt-get install -y snappy
ln -sf /usr/lib64/libsnappy.so.1 /root/hadoop-native/. || true

# Create /usr/bin/realpath which is used by R to find Java installations
# NOTE: /usr/bin/realpath is missing in CentOS AMIs. See
# http://superuser.com/questions/771104/usr-bin-realpath-not-found-in-centos-6-5

# not needed now atleast, we'll let it stay here
echo '#!/bin/bash' > /usr/bin/realpath
echo 'readlink -e "$@"' >> /usr/bin/realpath
chmod a+x /usr/bin/realpath
