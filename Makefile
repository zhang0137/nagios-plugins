#
#  Author: Hari Sekhon
#  Date: 2013-02-03 10:25:36 +0000 (Sun, 03 Feb 2013)
#
#  http://github.com/harisekhon
#

.PHONY: install
install:
	@#@ [ $$EUID -eq 0 ] || { echo "error: must be root to install cpan modules"; exit 1; }
	@# putting modules one per line just for ease of maintenance
	#
	# Dependencies:
	#
	# DBD::mysql
	#
	# yum install perl-DBD-MySQL.x86_64
	#
	# if building CPAN module then
	#
	# yum install mysql mysql-devel  (need to start MySQL for make test to pass)
	#
	#
	# XML::Simple
	#
	# yum install expat-devel
	# 	or
	# apt-get install libexpat1-dev
	#
	sudo cpan \
		Class:Accessor \
		Data::Dumper \
		DBD::mysql \
		DBI \
		Digest::SHA \
		JSON \
		JSON:XS \
		LWP::Simple \
		LWP::UserAgent \
		Net::Async::CassandraCQL \
		MongoDB::MongoClient \
		Net::DNS \
		Net::SSH::Expect \
		Thrift \
		Time::HiRes \
		SMS::AQL \
		XML::Simple \
		; echo
	# Intentionally ignoring CPAN module build failures since some modules may fail for a multitude of reasons but this isn't really important unless you need the pieces of code that use them in which case you can solve those dependencies later
	git submodule init
	git submodule update

# Net::ZooKeeper must be done separately due to the C library dependency it fails when attempting to install directly from CPAN. You will also need Net::ZooKeeper for check_zookeeper_znode.pl to be, see README.md or instructions at https://github.com/harisekhon/nagios-plugins
ZOOKEEPER_VERSION = 3.4.5
.PHONY: zookeeper
zookeeper:
	[ -f zookeeper-$(ZOOKEEPER_VERSION).tar.gz ] || wget -O zookeeper-$(ZOOKEEPER_VERSION).tar.gz http://www.mirrorservice.org/sites/ftp.apache.org/zookeeper/zookeeper-$(ZOOKEEPER_VERSION)/zookeeper-$(ZOOKEEPER_VERSION).tar.gz
	[ -d zookeeper-$(ZOOKEEPER_VERSION) ] || tar zxvf zookeeper-$(ZOOKEEPER_VERSION).tar.gz
	cd zookeeper-$(ZOOKEEPER_VERSION)/src/c; 				./configure
	cd zookeeper-$(ZOOKEEPER_VERSION)/src/c; 				make
	cd zookeeper-$(ZOOKEEPER_VERSION)/src/c; 				sudo make install
	cd zookeeper-$(ZOOKEEPER_VERSION)/src/contrib/zkperl; 	perl Makefile.PL --zookeeper-include=/usr/local/include/zookeeper --zookeeper-lib=/usr/local/lib
	cd zookeeper-$(ZOOKEEPER_VERSION)/src/contrib/zkperl; 	LD_RUN_PATH=/usr/local/lib make
	cd zookeeper-$(ZOOKEEPER_VERSION)/src/contrib/zkperl; 	sudo make install
	perl -e "use Net::ZooKeeper"

.PHONY: clean
clean:
	rm -fr zookeeper-$(ZOOKEEPER_VERSION).tar.gz zookeeper-$(ZOOKEEPER_VERSION)
