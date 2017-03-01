#!./tcltestrunner.lua

# 2011 June 21
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.
#
#***********************************************************************
#
# This file contains tests for SQLite. Specifically, it tests that SQLite
# does not crash and an error is returned if localhost() fails. This 
# is the problem reported by ticket bd484a090c.
#

set testdir [file dirname $argv0]
source $testdir/tester.tcl

set testprefix tkt-bd484a090c


do_test 1.1 {
  lindex [catchsql { SELECT datetime('now', 'localtime') }] 0
} {0}
do_test 1.2 {
  lindex [catchsql { SELECT datetime('now', 'utc') }] 0
} {0}

sqlite3_test_control SQLITE_TESTCTRL_LOCALTIME_FAULT 1

do_test 2.1 {
  catchsql { SELECT datetime('now', 'localtime') }
} {1 {local time unavailable}}
do_test 2.2 {
  catchsql { SELECT datetime('now', 'utc') }
} {1 {local time unavailable}}

sqlite3_test_control SQLITE_TESTCTRL_LOCALTIME_FAULT 0

finish_test
