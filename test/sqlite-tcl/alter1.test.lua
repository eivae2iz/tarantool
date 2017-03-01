#!./tcltestrunner.lua

# 2004 November 10
#
# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.
#
#*************************************************************************
# This file implements regression tests for SQLite library.  The
# focus of this script is testing the ALTER TABLE statement.
#
# $Id: alter.test,v 1.32 2009/03/24 15:08:10 drh Exp $
#

set testdir [file dirname $argv0]
source $testdir/tester.tcl

# If SQLITE_OMIT_ALTERTABLE is defined, omit this file.
ifcapable !altertable {
  finish_test
  return
}

#----------------------------------------------------------------------
# Test organization:
#
# alter-1.1.* - alter-1.7.*: Basic tests of ALTER TABLE, including tables
#     with implicit and explicit indices. These tests came from an earlier
#     fork of SQLite that also supported ALTER TABLE.
# alter-1.8.*: Tests for ALTER TABLE when the table resides in an 
#     attached database.
# alter-1.9.*: Tests for ALTER TABLE when their is whitespace between the
#     table name and left parenthesis token. i.e: 
#     "CREATE TABLE abc       (a, b, c);"
# alter-2.*: Test error conditions and messages.
# alter-3.*: Test ALTER TABLE on tables that have TRIGGERs attached to them.
# alter-4.*: Test ALTER TABLE on tables that have AUTOINCREMENT fields.
# ...
# alter-12.*: Test ALTER TABLE on views.
#

# Create some tables to rename.  Be sure to include some TEMP tables
# and some tables with odd names.
#
do_test alter-1.1 {
  ifcapable tempdb {
    set ::temp TEMP
  } else {
    set ::temp {}
  }
  execsql [subst -nocommands {
    CREATE TABLE t1(id primary key, a,b);
    INSERT INTO t1 VALUES(1, 1,2);
    CREATE TABLE [t1x1](c UNIQUE, b PRIMARY KEY);
    INSERT INTO [t1x1] VALUES(3,4);
    CREATE INDEX t1i1 ON T1(B);
    CREATE INDEX t1i2 ON t1(a,b);
    CREATE INDEX i3 ON [t1x1](b,c);
    CREATE $::temp TABLE "temp_table"(id primary key, e,f,g UNIQUE);
    CREATE INDEX i2 ON [temp_table](f);
    INSERT INTO [temp_table] VALUES(1,5,6,7);
  }]
  execsql {
    SELECT 't1', a,b FROM t1;
    SELECT 't1x1', * FROM "t1x1";
    SELECT e,f,g FROM [temp_table];
  }
} {t1 1 2 t1x1 3 4 5 6 7}
# do_test alter-1.2 {
#   execsql [subst {
#     CREATE $::temp TABLE objlist(type, name, tbl_name);
#     INSERT INTO objlist SELECT type, name, tbl_name 
#         FROM sqlite_master WHERE NAME!='objlist';
#   }]
#   ifcapable tempdb {
#     execsql {
#       INSERT INTO objlist SELECT type, name, tbl_name 
#           FROM sqlite_temp_master WHERE NAME!='objlist';
#     }
#   }

#   execsql {
#     SELECT type, name, tbl_name FROM objlist ORDER BY tbl_name, type desc, name;
#   }
# } [list \
#      table t1                              t1             \
#      index t1i1                            t1             \
#      index t1i2                            t1             \
#      table t1x1                           t1x1          \
#      index i3                              t1x1          \
#      index {sqlite_autoindex_t1x1_1}      t1x1          \
#      index {sqlite_autoindex_t1x1_2}      t1x1          \
#      table {temp table}                    {temp table}   \
#      index i2                              {temp table}   \
#      index {sqlite_autoindex_temp table_1} {temp table}   \
#   ]

# MUST_WORK_TEST

# # Make some changes
# #
# integrity_check alter-1.3.0
# do_test alter-1.3 {
#   execsql {
#     ALTER TABLE [T1] RENAME to [-t1-];
#     ALTER TABLE "t1x1" RENAME TO T2;
#     ALTER TABLE [temp table] RENAME to TempTab;
#   }
# } {}

# integrity_check alter-1.3.1

# MUST_WORK_TEST

# do_test alter-1.4 {
#   execsql {
#     SELECT 't1', * FROM [-t1-];
#     SELECT 't2', * FROM t2;
#     SELECT * FROM temptab;
#   }
# } {t1 1 2 t2 3 4 5 6 7}


# do_test alter-1.5 {
#   execsql {
#     DELETE FROM objlist;
#     INSERT INTO objlist SELECT type, name, tbl_name
#         FROM sqlite_master WHERE NAME!='objlist';
#   }
#   catchsql {
#     INSERT INTO objlist SELECT type, name, tbl_name 
#         FROM sqlite_temp_master WHERE NAME!='objlist';
#   }
#   execsql {
#     SELECT type, name, tbl_name FROM objlist ORDER BY tbl_name, type desc, name;
#   }
# } [list \
#      table -t1-                         -t1-        \
#      index t1i1                         -t1-        \
#      index t1i2                         -t1-        \
#      table T2                           T2          \
#      index i3                           T2          \
#      index {sqlite_autoindex_T2_1}      T2          \
#      index {sqlite_autoindex_T2_2}      T2          \
#      table {TempTab}                    {TempTab}   \
#      index i2                           {TempTab}   \
#      index {sqlite_autoindex_TempTab_1} {TempTab}   \
#   ]

# # Make sure the changes persist after restarting the database.
# # (The TEMP table will not persist, of course.)
# #
# ifcapable tempdb {
#   do_test alter-1.6 {
#     db close
#     sqlite3 db test.db
#     set DB [sqlite3_connection_pointer db]
#     execsql {
#       CREATE TEMP TABLE objlist(type, name, tbl_name);
#       INSERT INTO objlist SELECT type, name, tbl_name FROM sqlite_master;
#       INSERT INTO objlist 
#           SELECT type, name, tbl_name FROM sqlite_temp_master 
#           WHERE NAME!='objlist';
#       SELECT type, name, tbl_name FROM objlist 
#           ORDER BY tbl_name, type desc, name;
#     }
#   } [list \
#        table -t1-                         -t1-           \
#        index t1i1                         -t1-           \
#        index t1i2                         -t1-           \
#        table T2                           T2          \
#        index i3                           T2          \
#        index {sqlite_autoindex_T2_1}      T2          \
#        index {sqlite_autoindex_T2_2}      T2          \
#     ]
# } else {
#   execsql {
#     DROP TABLE TempTab;
#   }
# }

# Create bogus application-defined functions for functions used 
# internally by ALTER TABLE, to ensure that ALTER TABLE falls back
# to the built-in functions.
#
proc failing_app_func {args} {error "bad function"}
do_test alter-1.7-prep {
  db func substr failing_app_func
  db func like failing_app_func
  db func sqlite_rename_table failing_app_func
  db func sqlite_rename_trigger failing_app_func
  db func sqlite_rename_parent failing_app_func
  #catchsql {SELECT substr(name,1,3) FROM sqlite_master}
} {}

# # Make sure the ALTER TABLE statements work with the
# # non-callback API
# #
# do_test alter-1.7 {

# MUST_WORK_TEST

#   stepsql $DB {
#     ALTER TABLE [-t1-] RENAME to [*t1*];
#     ALTER TABLE T2 RENAME TO [<t2>];
#   }

#   execsql {
#     DELETE FROM objlist;
#     INSERT INTO objlist SELECT type, name, tbl_name
#         FROM sqlite_master WHERE NAME!='objlist';
#   }
#   catchsql {
#     INSERT INTO objlist SELECT type, name, tbl_name 
#         FROM sqlite_temp_master WHERE NAME!='objlist';
#   }
#   execsql {
#     SELECT type, name, tbl_name FROM objlist ORDER BY tbl_name, type desc, name;
#   }
# } [list \
#      table *t1*                         *t1*           \
#      index t1i1                         *t1*           \
#      index t1i2                         *t1*           \
#      table <t2>                         <t2>          \
#      index i3                           <t2>          \
#      index {sqlite_autoindex_<t2>_1}    <t2>          \
#      index {sqlite_autoindex_<t2>_2}    <t2>          \
#   ]

# # Check that ALTER TABLE works on attached databases.
# #
# ifcapable attach {
#   do_test alter-1.8.1 {
#     forcedelete test2.db
#     forcedelete test2.db-journal
#     execsql {
#       ATTACH 'test2.db' AS aux;
#     }
#   } {}
#   do_test alter-1.8.2 {
#     execsql {
#       CREATE TABLE t4(a PRIMARY KEY, b, c);
#       CREATE TABLE aux.t4(a PRIMARY KEY, b, c);
#       CREATE INDEX i4 ON t4(b);
#       CREATE INDEX aux.i4 ON t4(b);
#     }
#   } {}
#   do_test alter-1.8.3 {
#     execsql {
#       INSERT INTO t4 VALUES('main', 'main', 'main');
#       INSERT INTO aux.t4 VALUES('aux', 'aux', 'aux');
#       SELECT * FROM t4 WHERE a = 'main';
#     }
#   } {main main main}
#   do_test alter-1.8.4 {
#     execsql {
#       ALTER TABLE t4 RENAME TO t5;
#       SELECT * FROM t4 WHERE a = 'aux';
#     }
#   } {aux aux aux}
#   do_test alter-1.8.5 {
#     execsql {
#       SELECT * FROM t5;
#     }
#   } {main main main}
#   do_test alter-1.8.6 {
#     execsql {
#       SELECT * FROM t5 WHERE b = 'main';
#     }
#   } {main main main}
#   do_test alter-1.8.7 {
#     execsql {
#       ALTER TABLE aux.t4 RENAME TO t5;
#       SELECT * FROM aux.t5 WHERE b = 'aux';
#     }
#   } {aux aux aux}
# }

do_test alter-1.9.1 {
  execsql {
    CREATE TABLE tbl1   (a primary key, b, c);
    INSERT INTO tbl1 VALUES(1, 2, 3);
  }
} {}
do_test alter-1.9.2 {
  execsql {
    SELECT * FROM tbl1;
  }
} {1 2 3}

# MUST_WORK_TEST

# do_test alter-1.9.3 {
#   execsql {
#     ALTER TABLE tbl1 RENAME TO tbl2;
#     SELECT * FROM tbl2;
#   }
# } {1 2 3}
# do_test alter-1.9.4 {
#   execsql {
#     DROP TABLE tbl2;
#   }
# } {}

# Test error messages
#
do_test alter-2.1 {
  catchsql {
    ALTER TABLE none RENAME TO hi;
  }
} {1 {no such table: none}}

# MUST_WORK_TEST

# do_test alter-2.2 {
#   execsql {
#     CREATE TABLE t3(p,q,r);
#   }
#   catchsql {
#     ALTER TABLE [<t2>] RENAME TO t3;
#   }
# } {1 {there is already another table or index with this name: t3}}
# do_test alter-2.3 {
#   catchsql {
#     ALTER TABLE [<t2>] RENAME TO i3;
#   }
# } {1 {there is already another table or index with this name: i3}}

# do_test alter-2.4 {
#   catchsql {
#     ALTER TABLE SqLiTe_master RENAME TO master;
#   }
# } {1 {table sqlite_master may not be altered}}
# do_test alter-2.5 {
#   catchsql {
#     ALTER TABLE t3 RENAME TO sqlite_t3;
#   }
# } {1 {object name reserved for internal use: sqlite_t3}}

# MUST_WORK_TEST

# do_test alter-2.6 {
#   catchsql {
#     ALTER TABLE t3 ADD COLUMN (ALTER TABLE t3 ADD COLUMN);
#   }
# } {1 {near "(": syntax error}}

# # If this compilation does not include triggers, omit the alter-3.* tests.
# ifcapable trigger {

# #-----------------------------------------------------------------------
# # Tests alter-3.* test ALTER TABLE on tables that have triggers.
# #
# # alter-3.1.*: ALTER TABLE with triggers.
# # alter-3.2.*: Test that the ON keyword cannot be used as a database,
# #     table or column name unquoted. This is done because part of the
# #     ALTER TABLE code (specifically the implementation of SQL function
# #     "sqlite_alter_trigger") will break in this case.
# # alter-3.3.*: ALTER TABLE with TEMP triggers (todo).
# #

# An SQL user-function for triggers to fire, so that we know they
# are working.
proc trigfunc {args} {
  set ::TRIGGER $args
}
db func trigfunc trigfunc

# MUST_WORK_TEST

# do_test alter-3.1.0 {
#   execsql {
#     CREATE TABLE t6(a, b, c);
#     -- Different case for the table name in the trigger.
#     CREATE TRIGGER trig1 AFTER INSERT ON T6 BEGIN
#       SELECT trigfunc('trig1', new.a, new.b, new.c);
#     END;
#   }
# } {}
# do_test alter-3.1.1 {
#   execsql {
#     INSERT INTO t6 VALUES(1, 2, 3);
#   }
#   set ::TRIGGER
# } {trig1 1 2 3}
# do_test alter-3.1.2 {
#   execsql {
#     ALTER TABLE t6 RENAME TO t7;
#     INSERT INTO t7 VALUES(4, 5, 6);
#   }
#   set ::TRIGGER
# } {trig1 4 5 6}
# do_test alter-3.1.3 {
#   execsql {
#     DROP TRIGGER trig1;
#   }
# } {}
# do_test alter-3.1.4 {
#   execsql {
#     CREATE TRIGGER trig2 AFTER INSERT ON main.t7 BEGIN
#       SELECT trigfunc('trig2', new.a, new.b, new.c);
#     END;
#     INSERT INTO t7 VALUES(1, 2, 3);
#   }
#   set ::TRIGGER
# } {trig2 1 2 3}
# do_test alter-3.1.5 {
#   execsql {
#     ALTER TABLE t7 RENAME TO t8;
#     INSERT INTO t8 VALUES(4, 5, 6);
#   }
#   set ::TRIGGER
# } {trig2 4 5 6}
# do_test alter-3.1.6 {
#   execsql {
#     DROP TRIGGER trig2;
#   }
# } {}
# do_test alter-3.1.7 {
#   execsql {
#     CREATE TRIGGER trig3 AFTER INSERT ON main.'t8'BEGIN
#       SELECT trigfunc('trig3', new.a, new.b, new.c);
#     END;
#     INSERT INTO t8 VALUES(1, 2, 3);
#   }
#   set ::TRIGGER
# } {trig3 1 2 3}
# do_test alter-3.1.8 {
#   execsql {
#     ALTER TABLE t8 RENAME TO t9;
#     INSERT INTO t9 VALUES(4, 5, 6);
#   }
#   set ::TRIGGER
# } {trig3 4 5 6}

# # Make sure "ON" cannot be used as a database, table or column name without
# # quoting. Otherwise the sqlite_alter_trigger() function might not work.
# forcedelete test3.db
# forcedelete test3.db-journal
# ifcapable attach {
#   do_test alter-3.2.1 {
#     catchsql {
#       ATTACH 'test3.db' AS ON;
#     }
#   } {1 {near "ON": syntax error}}
#   do_test alter-3.2.2 {
#     catchsql {
#       ATTACH 'test3.db' AS 'ON';
#     }
#   } {0 {}}
#   do_test alter-3.2.3 {
#     catchsql {
#       CREATE TABLE ON.t1(a, b, c); 
#     }
#   } {1 {near "ON": syntax error}}
#   do_test alter-3.2.4 {
#     catchsql {
#       CREATE TABLE 'ON'.t1(a, b, c); 
#     }
#   } {0 {}}
#   do_test alter-3.2.4 {
#     catchsql {
#       CREATE TABLE 'ON'.ON(a, b, c); 
#     }
#   } {1 {near "ON": syntax error}}
#   do_test alter-3.2.5 {
#     catchsql {
#       CREATE TABLE 'ON'.'ON'(a, b, c); 
#     }
#   } {0 {}}
# }
do_test alter-3.2.6 {
  catchsql {
    CREATE TABLE t10(a, ON, c);
  }
} {1 {near "ON": syntax error}}
do_test alter-3.2.7 {
  catchsql {
    CREATE TABLE t10(a primary key, 'ON', c);
  }
} {0 {}}
# do_test alter-3.2.8 {
#   catchsql {
#     CREATE TRIGGER trig4 AFTER INSERT ON ON BEGIN SELECT 1; END;
#   }
# } {1 {near "ON": syntax error}}
# ifcapable attach {
#   do_test alter-3.2.9 {
#     catchsql {
#       CREATE TRIGGER 'on'.trig4 AFTER INSERT ON 'ON' BEGIN SELECT 1; END;
#     }
#   } {0 {}}
# }
# do_test alter-3.2.10 {
#   execsql {
#     DROP TABLE t10;
#   }
# } {}

# do_test alter-3.3.1 {
#   execsql [subst {
#     CREATE TABLE tbl1(a, b, c);
#     CREATE $::temp TRIGGER trig1 AFTER INSERT ON tbl1 BEGIN
#       SELECT trigfunc('trig1', new.a, new.b, new.c);
#     END;
#   }]
# } {}
# do_test alter-3.3.2 {
#   execsql {
#     INSERT INTO tbl1 VALUES('a', 'b', 'c');
#   }
#   set ::TRIGGER
# } {trig1 a b c}
# do_test alter-3.3.3 {
#   execsql {
#     ALTER TABLE tbl1 RENAME TO tbl2;
#     INSERT INTO tbl2 VALUES('d', 'e', 'f');
#   } 
#   set ::TRIGGER
# } {trig1 d e f}
# do_test alter-3.3.4 {
#   execsql [subst {
#     CREATE $::temp TRIGGER trig2 AFTER UPDATE ON tbl2 BEGIN
#       SELECT trigfunc('trig2', new.a, new.b, new.c);
#     END;
#   }] 
# } {}
# do_test alter-3.3.5 {
#   execsql {
#     ALTER TABLE tbl2 RENAME TO tbl3;
#     INSERT INTO tbl3 VALUES('g', 'h', 'i');
#   } 
#   set ::TRIGGER
# } {trig1 g h i}
# do_test alter-3.3.6 {
#   execsql {
#     UPDATE tbl3 SET a = 'G' where a = 'g';
#   } 
#   set ::TRIGGER
# } {trig2 G h i}
# do_test alter-3.3.7 {
#   execsql {
#     DROP TABLE tbl3;
#   }
# } {}
# ifcapable tempdb {
#   do_test alter-3.3.8 {
#     execsql {
#       SELECT * FROM sqlite_temp_master WHERE type = 'trigger';
#     }
#   } {}
# }

# } ;# ifcapable trigger

# If the build does not include AUTOINCREMENT fields, omit alter-4.*.
ifcapable autoinc {

execsql {DROP TABLE IF EXISTS tbl1}

do_test alter-4.1 {
  execsql {
    CREATE TABLE tbl1(a INTEGER PRIMARY KEY AUTOINCREMENT);
    INSERT INTO tbl1 VALUES(10);
  }
} {}
do_test alter-4.2 {
  execsql {
    INSERT INTO tbl1 VALUES(NULL);
    SELECT a FROM tbl1;
  }
} {10 11}

# MUST_WORK_TEST

# do_test alter-4.3 {
#   execsql {
#     ALTER TABLE tbl1 RENAME TO tbl2;
#     DELETE FROM tbl2;
#     INSERT INTO tbl2 VALUES(NULL);
#     SELECT a FROM tbl2;
#   }
# } {12}
# do_test alter-4.4 {
#   execsql {
#     DROP TABLE tbl2;
#   }
# } {}

} ;# ifcapable autoinc

# Test that it is Ok to execute an ALTER TABLE immediately after
# opening a database.

# MUST_WORK_TEST

# do_test alter-5.1 {
#   execsql {
#     CREATE TABLE tbl1(a primary key, b, c);
#     INSERT INTO tbl1 VALUES('x', 'y', 'z');
#   }
# } {}
# do_test alter-5.2 {
#   sqlite3 db2 test.db
#   execsql {
#     ALTER TABLE tbl1 RENAME TO tbl2;
#     SELECT * FROM tbl2;
#   } db2
# } {x y z}
# do_test alter-5.3 {
#   db2 close
# } {}

# foreach tblname [execsql {
#   SELECT name FROM sqlite_master
#    WHERE type='table' AND name NOT GLOB 'sqlite*'
# }] {
#   execsql "DROP TABLE \"$tblname\""
# }

set ::tbl_name "abc\uABCDdef"
do_test alter-6.1 {
  string length $::tbl_name
} {7}
# do_test alter-6.2 {
#   execsql "
#     CREATE TABLE ${tbl_name}(a, b, c);
#   "
#   set ::oid [execsql {SELECT max(oid) FROM sqlite_master}]
#   execsql "
#     SELECT sql FROM sqlite_master WHERE oid = $::oid;
#   "
# } "{CREATE TABLE ${::tbl_name}(a, b, c)}"
# execsql "
#   SELECT * FROM ${::tbl_name}
# "
# set ::tbl_name2 "abcXdef"
# do_test alter-6.3 {
#   execsql "
#     ALTER TABLE $::tbl_name RENAME TO $::tbl_name2 
#   "
#   execsql "
#     SELECT sql FROM sqlite_master WHERE oid = $::oid
#   "
# } "{CREATE TABLE \"${::tbl_name2}\"(a, b, c)}"
# do_test alter-6.4 {
#   execsql "
#     ALTER TABLE $::tbl_name2 RENAME TO $::tbl_name
#   "
#   execsql "
#     SELECT sql FROM sqlite_master WHERE oid = $::oid
#   "
# } "{CREATE TABLE \"${::tbl_name}\"(a, b, c)}"
# set ::col_name ghi\1234\jkl
# do_test alter-6.5 {
#   execsql "
#     ALTER TABLE $::tbl_name ADD COLUMN $::col_name VARCHAR
#   "
#   execsql "
#     SELECT sql FROM sqlite_master WHERE oid = $::oid
#   "
# } "{CREATE TABLE \"${::tbl_name}\"(a, b, c, $::col_name VARCHAR)}"
# set ::col_name2 B\3421\A
# do_test alter-6.6 {
#   db close
#   sqlite3 db test.db
#   execsql "
#     ALTER TABLE $::tbl_name ADD COLUMN $::col_name2
#   "
#   execsql "
#     SELECT sql FROM sqlite_master WHERE oid = $::oid
#   "
# } "{CREATE TABLE \"${::tbl_name}\"(a, b, c, $::col_name VARCHAR, $::col_name2)}"
# do_test alter-6.7 {
#   execsql "
#     INSERT INTO ${::tbl_name} VALUES(1, 2, 3, 4, 5);
#     SELECT $::col_name, $::col_name2 FROM $::tbl_name;
#   "
# } {4 5}

# MUST_WORK_TEST

# # Ticket #1665:  Make sure ALTER TABLE ADD COLUMN works on a table
# # that includes a COLLATE clause.
# #
# do_realnum_test alter-7.1 {
#   execsql {
#     CREATE TABLE t1(a TEXT COLLATE BINARY);
#     ALTER TABLE t1 ADD COLUMN b INTEGER COLLATE NOCASE;
#     INSERT INTO t1 VALUES(1,'-2');
#     INSERT INTO t1 VALUES(5.4e-08,'5.4e-08');
#     SELECT typeof(a), a, typeof(b), b FROM t1;
#   }
# } {text 1 integer -2 text 5.4e-08 real 5.4e-08}

# MUST_WORK_TEST

# # Make sure that when a column is added by ALTER TABLE ADD COLUMN and has
# # a default value that the default value is used by aggregate functions.
# #
# do_test alter-8.1 {
#   execsql {
#     CREATE TABLE t2(a INTEGER);
#     INSERT INTO t2 VALUES(1);
#     INSERT INTO t2 VALUES(1);
#     INSERT INTO t2 VALUES(2);
#     ALTER TABLE t2 ADD COLUMN b INTEGER DEFAULT 9;
#     SELECT sum(b) FROM t2;
#   }
# } {27}
# do_test alter-8.2 {
#   execsql {
#     SELECT a, sum(b) FROM t2 GROUP BY a;
#   }
# } {1 18 2 9}

# #--------------------------------------------------------------------------
# # alter-9.X - Special test: Make sure the sqlite_rename_trigger() and
# # rename_table() functions do not crash when handed bad input.
# #
# ifcapable trigger {
#   do_test alter-9.1 {
#     execsql {SELECT SQLITE_RENAME_TRIGGER(0,0)}
#   } {{}}
# }
# do_test alter-9.2 {
#   execsql {
#     SELECT SQLITE_RENAME_TABLE(0,0);
#     SELECT SQLITE_RENAME_TABLE(10,20);
#     SELECT SQLITE_RENAME_TABLE('foo', 'foo');
#   }
# } {{} {} {}}

# MUST_WORK_TEST

# #------------------------------------------------------------------------
# # alter-10.X - Make sure ALTER TABLE works with multi-byte UTF-8 characters 
# # in the names.
# #
# do_test alter-10.1 {
#   execsql "CREATE TABLE xyz(x UNIQUE)"
#   execsql "ALTER TABLE xyz RENAME TO xyz\u1234abc"
#   execsql {SELECT name FROM sqlite_master WHERE name GLOB 'xyz*'}
# } [list xyz\u1234abc]
# do_test alter-10.2 {
#   execsql {SELECT name FROM sqlite_master WHERE name GLOB 'sqlite_autoindex*'}
# } [list sqlite_autoindex_xyz\u1234abc_1]
# do_test alter-10.3 {
#   execsql "ALTER TABLE xyz\u1234abc RENAME TO xyzabc"
#   execsql {SELECT name FROM sqlite_master WHERE name GLOB 'xyz*'}
# } [list xyzabc]
# do_test alter-10.4 {
#   execsql {SELECT name FROM sqlite_master WHERE name GLOB 'sqlite_autoindex*'}
# } [list sqlite_autoindex_xyzabc_1]

# do_test alter-11.1 {
#   sqlite3_exec db {CREATE TABLE t11(%c6%c6)}
#   execsql {
#     ALTER TABLE t11 ADD COLUMN abc;
#   }
#   catchsql {
#     ALTER TABLE t11 ADD COLUMN abc;
#   }
# } {1 {duplicate column name: abc}}
# set isutf16 [regexp 16 [db one {PRAGMA encoding}]]
# if {!$isutf16} {
#   do_test alter-11.2 {
#     execsql {INSERT INTO t11 VALUES(1,2)}
#     sqlite3_exec db {SELECT %c6%c6 AS xyz, abc FROM t11}
#   } {0 {xyz abc 1 2}}
# }
# do_test alter-11.3 {
#   sqlite3_exec db {CREATE TABLE t11b("%81%82%83" text)}
#   execsql {
#     ALTER TABLE t11b ADD COLUMN abc;
#   }
#   catchsql {
#     ALTER TABLE t11b ADD COLUMN abc;
#   }
# } {1 {duplicate column name: abc}}
# if {!$isutf16} {
#   do_test alter-11.4 {
#     execsql {INSERT INTO t11b VALUES(3,4)}
#     sqlite3_exec db {SELECT %81%82%83 AS xyz, abc FROM t11b}
#   } {0 {xyz abc 3 4}}
#   do_test alter-11.5 {
#     sqlite3_exec db {SELECT [%81%82%83] AS xyz, abc FROM t11b}
#   } {0 {xyz abc 3 4}}
#   do_test alter-11.6 {
#     sqlite3_exec db {SELECT "%81%82%83" AS xyz, abc FROM t11b}
#   } {0 {xyz abc 3 4}}
# }
# do_test alter-11.7 {
#   sqlite3_exec db {CREATE TABLE t11c(%81%82%83 text)}
#   execsql {
#     ALTER TABLE t11c ADD COLUMN abc;
#   }
#   catchsql {
#     ALTER TABLE t11c ADD COLUMN abc;
#   }
# } {1 {duplicate column name: abc}}
# if {!$isutf16} {
#   do_test alter-11.8 {
#     execsql {INSERT INTO t11c VALUES(5,6)}
#     sqlite3_exec db {SELECT %81%82%83 AS xyz, abc FROM t11c}
#   } {0 {xyz abc 5 6}}
#   do_test alter-11.9 {
#     sqlite3_exec db {SELECT [%81%82%83] AS xyz, abc FROM t11c}
#   } {0 {xyz abc 5 6}}
#   do_test alter-11.10 {
#     sqlite3_exec db {SELECT "%81%82%83" AS xyz, abc FROM t11c}
#   } {0 {xyz abc 5 6}}
# }

do_test alter-12.1 {
  execsql {
    CREATE TABLE t12(a primary key, b, c);
    CREATE VIEW v1 AS SELECT * FROM t12;
  }
} {}
do_test alter-12.2 {
  catchsql {
    ALTER TABLE v1 RENAME TO v2;
  }
} {1 {view v1 may not be altered}}
do_test alter-12.3 {
  execsql { SELECT * FROM v1; }
} {}
do_test alter-12.4 {
  db close
  sqlite3 db test.db
  execsql { SELECT * FROM v1; }
} {}
do_test alter-12.5 {
  catchsql { 
    ALTER TABLE v1 ADD COLUMN new_column;
  }
} {1 {Cannot add a column to a view}}

# MUST_WORK_TEST

# # Ticket #3102:
# # Verify that comments do not interfere with the table rename
# # algorithm.
# #
# do_test alter-13.1 {
#   execsql {
#     CREATE TABLE /* hi */ t3102a(x);
#     CREATE TABLE t3102b -- comment
#     (y);
#     CREATE INDEX t3102c ON t3102a(x);
#     SELECT name FROM sqlite_master WHERE name GLOB 't3102*' ORDER BY 1;
#   }
# } {t3102a t3102b t3102c}
# do_test alter-13.2 {
#   execsql {
#     ALTER TABLE t3102a RENAME TO t3102a_rename;
#     SELECT name FROM sqlite_master WHERE name GLOB 't3102*' ORDER BY 1;
#   }
# } {t3102a_rename t3102b t3102c}
# do_test alter-13.3 {
#   execsql {
#     ALTER TABLE t3102b RENAME TO t3102b_rename;
#     SELECT name FROM sqlite_master WHERE name GLOB 't3102*' ORDER BY 1;
#   }
# } {t3102a_rename t3102b_rename t3102c}

# # Ticket #3651
# do_test alter-14.1 {
#   catchsql {
#     CREATE TABLE t3651(a UNIQUE);
#     ALTER TABLE t3651 ADD COLUMN b UNIQUE;
#   }
# } {1 {Cannot add a UNIQUE column}}
# do_test alter-14.2 {
#   catchsql {
#     ALTER TABLE t3651 ADD COLUMN b PRIMARY KEY;
#   }
# } {1 {Cannot add a PRIMARY KEY column}}


# #-------------------------------------------------------------------------
# # Test that it is not possible to use ALTER TABLE on any system table.
# #
# set system_table_list {1 sqlite_master}
# catchsql ANALYZE
# ifcapable analyze { lappend system_table_list 2 sqlite_stat1 }
# ifcapable stat3   { lappend system_table_list 3 sqlite_stat3 }
# ifcapable stat4   { lappend system_table_list 4 sqlite_stat4 }

# foreach {tn tbl} $system_table_list {
#   do_test alter-15.$tn.1 {
#     catchsql "ALTER TABLE $tbl RENAME TO xyz"
#   } [list 1 "table $tbl may not be altered"]

#   do_test alter-15.$tn.2 {
#     catchsql "ALTER TABLE $tbl ADD COLUMN xyz"
#   } [list 1 "table $tbl may not be altered"]
# }

# #------------------------------------------------------------------------
# # Verify that ALTER TABLE works on tables with the WITHOUT rowid option.
# #
# do_execsql_test alter-16.1 {
#   CREATE TABLE t16a(a TEXT, b REAL, c INT, PRIMARY KEY(a,b)) WITHOUT rowid;
#   INSERT INTO t16a VALUES('abc',1.25,99);
#   ALTER TABLE t16a ADD COLUMN d TEXT DEFAULT 'xyzzy';
#   INSERT INTO t16a VALUES('cba',5.5,98,'fizzle');
#   SELECT * FROM t16a ORDER BY a;
# } {abc 1.25 99 xyzzy cba 5.5 98 fizzle}
# do_execsql_test alter-16.2 {
#   ALTER TABLE t16a RENAME TO t16a_rn;
#   SELECT * FROM t16a_rn ORDER BY a;
# } {abc 1.25 99 xyzzy cba 5.5 98 fizzle}

# #-------------------------------------------------------------------------
# # Verify that NULL values into the internal-use-only sqlite_rename_*()
# # functions do not cause problems.
# #
# do_execsql_test alter-17.1 {
#   SELECT sqlite_rename_table('CREATE TABLE xyz(a,b,c)','abc');
# } {{CREATE TABLE "abc"(a,b,c)}}
# do_execsql_test alter-17.2 {
#   SELECT sqlite_rename_table('CREATE TABLE xyz(a,b,c)',NULL);
# } {{CREATE TABLE "(NULL)"(a,b,c)}}
# do_execsql_test alter-17.3 {
#   SELECT sqlite_rename_table(NULL,'abc');
# } {{}}
# do_execsql_test alter-17.4 {
#   SELECT sqlite_rename_trigger('CREATE TRIGGER r1 ON xyz WHEN','abc');
# } {{CREATE TRIGGER r1 ON "abc" WHEN}}
# do_execsql_test alter-17.5 {
#   SELECT sqlite_rename_trigger('CREATE TRIGGER r1 ON xyz WHEN',NULL);
# } {{CREATE TRIGGER r1 ON "(NULL)" WHEN}}
# do_execsql_test alter-17.6 {
#   SELECT sqlite_rename_trigger(NULL,'abc');
# } {{}}
# do_execsql_test alter-17.7 {
#   SELECT sqlite_rename_parent('CREATE TABLE t1(a REFERENCES "xyzzy")',
#          'xyzzy','lmnop');
# } {{CREATE TABLE t1(a REFERENCES "lmnop")}}
# do_execsql_test alter-17.8 {
#   SELECT sqlite_rename_parent('CREATE TABLE t1(a REFERENCES "xyzzy")',
#          'xyzzy',NULL);
# } {{CREATE TABLE t1(a REFERENCES "(NULL)")}}
# do_execsql_test alter-17.9 {
#   SELECT sqlite_rename_parent('CREATE TABLE t1(a REFERENCES "xyzzy")',
#          NULL, 'lmnop');
# } {{}}
# do_execsql_test alter-17.10 {
#   SELECT sqlite_rename_parent(NULL,'abc','xyz');
# } {{}}
# do_execsql_test alter-17.11 {
#   SELECT sqlite_rename_parent('create references ''','abc','xyz');
# } {{create references '}}
# do_execsql_test alter-17.12 {
#   SELECT sqlite_rename_parent('create references "abc"123" ','abc','xyz');
# } {{create references "xyz"123" }}
# do_execsql_test alter-17.13 {
#   SELECT sqlite_rename_parent("references '''",'abc','xyz');
# } {{references '''}}

finish_test
