#!./tcltestrunner.lua

# 2014 April 26
#
# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.
#
#***********************************************************************
# Test that ticket f67b41381a has been resolved.
#

set testdir [file dirname $argv0]
source $testdir/tester.tcl
set testprefix tkt-f67b41381a

# do_execsql_test 1.0 {
#   CREATE TABLE t1(a);
#   INSERT INTO t1 VALUES(1);
#   ALTER TABLE t1 ADD COLUMN b DEFAULT 2;
#   CREATE TABLE t2(a, b);
#   INSERT INTO t2 SELECT * FROM t1;
#   SELECT * FROM t2;
# } {1 2}

# db cache size 0
# foreach {tn tbls xfer} {
#   1 { CREATE TABLE t1(a, b); CREATE TABLE t2(a, b)             }             1
#   2 { CREATE TABLE t1(a, b DEFAULT 'x'); CREATE TABLE t2(a, b) }             0
#   3 { CREATE TABLE t1(a, b DEFAULT 'x'); CREATE TABLE t2(a, b DEFAULT 'x') } 1
#   4 { CREATE TABLE t1(a, b DEFAULT NULL); CREATE TABLE t2(a, b) }            0
#   5 { CREATE TABLE t1(a DEFAULT 2, b); CREATE TABLE t2(a DEFAULT 1, b) }     1
#   6 { CREATE TABLE t1(a DEFAULT 1, b); CREATE TABLE t2(a DEFAULT 1, b) }     1
#   7 { CREATE TABLE t1(a DEFAULT 1, b DEFAULT 1);
#       CREATE TABLE t2(a DEFAULT 3, b DEFAULT 1) }                            1
#   8 { CREATE TABLE t1(a DEFAULT 1, b DEFAULT 1);
#       CREATE TABLE t2(a DEFAULT 3, b DEFAULT 3) }                            0

# } {

#   execsql { DROP TABLE t1; DROP TABLE t2 }
#   execsql $tbls

#   set res 1
#   db eval { EXPLAIN INSERT INTO t1 SELECT * FROM t2 } {
#     if {$opcode == "Column"} { set res 0 }
#   }

#   do_test 2.$tn [list set res] $xfer
# }

finish_test
