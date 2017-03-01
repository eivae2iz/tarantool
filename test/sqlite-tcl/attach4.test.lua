#!./tcltestrunner.lua

# 200 July 1
#
# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.
#
#***********************************************************************
# This file implements regression tests for SQLite library.  The
# focus of this script is attaching many database files to a single
# connection.
#

set testdir [file dirname $argv0]
source $testdir/tester.tcl

set testprefix attach4

ifcapable !attach {
  finish_test
  return
}

# puts "Testing with SQLITE_MAX_ATTACHED=$SQLITE_MAX_ATTACHED"

# set files {main test.db}
# for {set ii 0} {$ii < $SQLITE_MAX_ATTACHED} {incr ii} {
#   lappend files aux$ii "test.db$ii"
# }

# do_test 1.1 {
#   sqlite3_limit db SQLITE_LIMIT_ATTACHED -1
# } $SQLITE_MAX_ATTACHED

# do_test 1.2.1 {
#   db close
#   foreach {name f} $files { forcedelete $f }
#   sqlite3 db test.db
  
#   foreach {name f} $files {
#     if {$name == "main"} continue
#     execsql "ATTACH '$f' AS $name"
#   }

#   db eval {PRAGMA database_list} {
#     lappend L $name [file tail $file]
#   }
#   set L
# } $files

# do_catchsql_test 1.2.2 {
#   ATTACH 'x.db' AS next;
# } [list 1 "too many attached databases - max $SQLITE_MAX_ATTACHED"]

# do_test 1.3 {
#   execsql BEGIN;
#   foreach {name f} $files {
#     execsql "CREATE TABLE $name.tbl(x)"
#     execsql "INSERT INTO $name.tbl VALUES('$f')"
#   }
#   execsql COMMIT;
# } {}

# do_test 1.4 {
#   set L [list]
#   foreach {name f} $files {
#     lappend L $name [execsql "SELECT x FROM $name.tbl"]
#   }
#   set L
# } $files

# set L [list]
# set S ""
# foreach {name f} $files {
#   if {[permutation] == "journaltest"} {
#     set mode delete
#   } else {
#     set mode wal
#   }
#   ifcapable !wal { set mode delete }
#   lappend L $mode
#   append S "
#     PRAGMA $name.journal_mode = WAL;
#     UPDATE $name.tbl SET x = '$name';
#   "
# }
# do_execsql_test 1.5 $S $L

# do_test 1.6 {
#   set L [list]
#   foreach {name f} $files {
#     lappend L [execsql "SELECT x FROM $name.tbl"] $f
#   }
#   set L
# } $files

# do_test 1.7 {
#   execsql BEGIN;
#   foreach {name f} $files {
#     execsql "UPDATE $name.tbl SET x = '$f'"
#   }
#   execsql COMMIT;
# } {}

# do_test 1.8 {
#   set L [list]
#   foreach {name f} $files {
#     lappend L $name [execsql "SELECT x FROM $name.tbl"]
#   }
#   set L
# } $files

# db close
# foreach {name f} $files { forcedelete $f }

finish_test
