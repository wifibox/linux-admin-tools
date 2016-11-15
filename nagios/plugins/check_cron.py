#!/usr/bin/python

import sys, os, time

cron_log = '/var/log/cron'
cron_pid = '/var/run/crond.pid'
cron_bin = '/usr/sbin/crond'

NAGIOS_OK = 0
NAGIOS_WARNING = 1
NAGIOS_CRITICAL = 2
NAGIOS_UNKNOWN = 3

# check for cron log file
try:
	mtime = os.path.getmtime(cron_log)
except OSError as e:
	print 'ERROR: %s' % (e)
	sys.exit(NAGIOS_UNKNOWN)

# check for cron pid file
try:
	fh = open(cron_pid)
	s = fh.readline()
	c_pid = str(s.strip())
except IOError as e:
	print "ERROR: Could not get Cron's PID file!", e
	sys.exit(NAGIOS_UNKNOWN)

# check for pid being cron daemon
try:
	c_path = '/proc/' + (c_pid) + '/exe'
	c_test = os.readlink(c_path)
except IOError as e:
	print "ERROR: can't get %s %s" %(c_path,e) 

if c_test != cron_bin:
	print "ERROR: link found in %s (%s) is does not points on %s binary" %(c_path,c_test,cron_bin)
	sys.exit(NAGIOS_CRITICAL)

now = time.time()

if int(now - mtime) < 3600:
	print "OK: Cron (PID: %s) is working (last log entry %s seconds ago)" %((c_pid),(str(int(now - mtime))))
	sys.exit(NAGIOS_OK)
else:
	print "ERROR: Cron is NOT running (last log entry %s seconds ago)" %(str(int(now - mtime)))
	sys.exit(NAGIOS_CRITICAL)

