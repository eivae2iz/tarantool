#!./tcltestrunner.lua

# 2005 August 13
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
# focus of this file is testing the LIKE and GLOB operators and
# in particular the optimizations that occur to help those operators
# run faster.
#
# $Id: like.test,v 1.13 2009/06/07 23:45:11 drh Exp $

set testdir [file dirname $argv0]
source $testdir/tester.tcl

# Create some sample data to work with.
#
do_test like-1.0 {
  execsql {
    CREATE TABLE t1(x TEXT PRIMARY KEY);
  }
  foreach str {
    a
    ab
    abc
    abcd

    acd
    abd
    bc
    bcd

    xyz
    ABC
    CDE
    {ABC abc xyz}
  } {
    db eval {INSERT INTO t1 VALUES(:str)}
  }
  execsql {
    SELECT count(*) FROM t1;
  }
} {12}

# Test that both case sensitive and insensitive version of LIKE work.
#
do_test like-1.1 {
  execsql {
    SELECT x FROM t1 WHERE x LIKE 'abc' ORDER BY 1;
  }
} {ABC abc}
do_test like-1.2 {
  execsql {
    SELECT x FROM t1 WHERE x GLOB 'abc' ORDER BY 1;
  }
} {abc}
do_test like-1.3 {
  execsql {
    SELECT x FROM t1 WHERE x LIKE 'ABC' ORDER BY 1;
  }
} {ABC abc}
do_test like-1.4 {
  execsql {
    SELECT x FROM t1 WHERE x LIKE 'aBc' ORDER BY 1;
  }
} {ABC abc}
do_test like-1.5.1 {
  # Use sqlite3_exec() to verify fix for ticket [25ee81271091] 2011-06-26
  sqlite3_exec db {PRAGMA case_sensitive_like=on}
} {0 {}}
do_test like-1.5.2 {
  execsql {
    SELECT x FROM t1 WHERE x LIKE 'abc' ORDER BY 1;
  }
} {abc}
do_test like-1.5.3 {
  execsql {
    PRAGMA case_sensitive_like; -- no argument; does not change setting
    SELECT x FROM t1 WHERE x LIKE 'abc' ORDER BY 1;
  }
} {abc}
do_test like-1.6 {
  execsql {
    SELECT x FROM t1 WHERE x GLOB 'abc' ORDER BY 1;
  }
} {abc}
do_test like-1.7 {
  execsql {
    SELECT x FROM t1 WHERE x LIKE 'ABC' ORDER BY 1;
  }
} {ABC}
do_test like-1.8 {
  execsql {
    SELECT x FROM t1 WHERE x LIKE 'aBc' ORDER BY 1;
  }
} {}
do_test like-1.9 {
  execsql {
    PRAGMA case_sensitive_like=off;
    SELECT x FROM t1 WHERE x LIKE 'abc' ORDER BY 1;
  }
} {ABC abc}
do_test like-1.10 {
  execsql {
    PRAGMA case_sensitive_like;  -- No argument, does not change setting.
    SELECT x FROM t1 WHERE x LIKE 'abc' ORDER BY 1;
  }
} {ABC abc}

# Tests of the REGEXP operator
#
do_test like-2.1 {
  proc test_regexp {a b} {
    return [regexp $a $b]
  }
  db function regexp -argcount 2 test_regexp
  execsql {
    SELECT x FROM t1 WHERE x REGEXP 'abc' ORDER BY 1;
  }
} {{ABC abc xyz} abc abcd}
do_test like-2.2 {
  execsql {
    SELECT x FROM t1 WHERE x REGEXP '^abc' ORDER BY 1;
  }
} {abc abcd}

# Tests of the MATCH operator
#
do_test like-2.3 {
  proc test_match {a b} {
    return [string match $a $b]
  }
  db function match -argcount 2 test_match
  execsql {
    SELECT x FROM t1 WHERE x MATCH '*abc*' ORDER BY 1;
  }
} {{ABC abc xyz} abc abcd}
do_test like-2.4 {
  execsql {
    SELECT x FROM t1 WHERE x MATCH 'abc*' ORDER BY 1;
  }
} {abc abcd}

# For the remaining tests, we need to have the like optimizations
# enabled.
#
ifcapable !like_opt {
  finish_test
  return
} 

# This procedure executes the SQL.  Then it appends to the result the
# "sort" or "nosort" keyword (as in the cksort procedure above) then
# it appends the names of the table and index used.
#
proc queryplan {sql} {
  set ::sqlite_sort_count 0
  set data [execsql $sql]
  if {$::sqlite_sort_count} {set x sort} {set x nosort}
  lappend data $x
  set eqp [execsql "EXPLAIN QUERY PLAN $sql"]
  # puts eqp=$eqp
  foreach {a b c x} $eqp {
    if {[regexp { TABLE (\w+ AS )?(\w+) USING COVERING INDEX (\w+)\y} \
        $x all as tab idx]} {
      lappend data {} $idx
    } elseif {[regexp { TABLE (\w+ AS )?(\w+) USING.* INDEX (\w+)\y} \
        $x all as tab idx]} {
      lappend data $tab $idx
    } elseif {[regexp { TABLE (\w+ AS )?(\w+)\y} $x all as tab]} {
      lappend data $tab *
    }
  }
  return $data   
}

# Perform tests on the like optimization.
#
# With no index on t1.x and with case sensitivity turned off, no optimization
# is performed.
#
do_test like-3.1 {
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t1 WHERE x LIKE 'abc%' ORDER BY 1;
  }
} {ABC {ABC abc xyz} abc abcd sort t1 *}
do_test like-3.2 {
  set sqlite_like_count
} {12}

# With an index on t1.x and case sensitivity on, optimize completely.
#
do_test like-3.3 {
  set sqlite_like_count 0
  execsql {
    PRAGMA case_sensitive_like=on;
    CREATE INDEX i1 ON t1(x);
  }
  queryplan {
    SELECT x FROM t1 WHERE x LIKE 'abc%' ORDER BY 1;
  }
} {abc abcd nosort {} i1}
do_test like-3.4 {
  set sqlite_like_count
} 0

# The LIKE optimization still works when the RHS is a string with no
# wildcard.  Ticket [e090183531fc2747]
#
do_test like-3.4.2 {
  queryplan {
    SELECT x FROM t1 WHERE x LIKE 'a' ORDER BY 1;
  }
} {a nosort {} i1}
do_test like-3.4.3 {
  queryplan {
    SELECT x FROM t1 WHERE x LIKE 'ab' ORDER BY 1;
  }
} {ab nosort {} i1}
do_test like-3.4.4 {
  queryplan {
    SELECT x FROM t1 WHERE x LIKE 'abcd' ORDER BY 1;
  }
} {abcd nosort {} i1}
do_test like-3.4.5 {
  queryplan {
    SELECT x FROM t1 WHERE x LIKE 'abcde' ORDER BY 1;
  }
} {nosort {} i1}


# Partial optimization when the pattern does not end in '%'
#
do_test like-3.5 {
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t1 WHERE x LIKE 'a_c' ORDER BY 1;
  }
} {abc nosort {} i1}
do_test like-3.6 {
  set sqlite_like_count
} 6
do_test like-3.7 {
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t1 WHERE x LIKE 'ab%d' ORDER BY 1;
  }
} {abcd abd nosort {} i1}
do_test like-3.8 {
  set sqlite_like_count
} 4
do_test like-3.9 {
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t1 WHERE x LIKE 'a_c%' ORDER BY 1;
  }
} {abc abcd nosort {} i1}
do_test like-3.10 {
  set sqlite_like_count
} 6

# No optimization when the pattern begins with a wildcard.
# Note that the index is still used but only for sorting.
#
do_test like-3.11 {
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t1 WHERE x LIKE '%bcd' ORDER BY 1;
  }
} {abcd bcd nosort {} i1}
do_test like-3.12 {
  set sqlite_like_count
} 12

# No optimization for case insensitive LIKE
#
do_test like-3.13 {
  set sqlite_like_count 0
  db eval {PRAGMA case_sensitive_like=off;}
  queryplan {
    SELECT x FROM t1 WHERE x LIKE 'abc%' ORDER BY 1;
  }
} {ABC {ABC abc xyz} abc abcd nosort {} i1}
do_test like-3.14 {
  set sqlite_like_count
} 12

# No optimization without an index.
#
do_test like-3.15 {
  set sqlite_like_count 0
  db eval {
    PRAGMA case_sensitive_like=on;
    DROP INDEX '517_1_i1';
  }
  queryplan {
    SELECT x FROM t1 WHERE x LIKE 'abc%' ORDER BY 1;
  }
} {abc abcd sort t1 *}
do_test like-3.16 {
  set sqlite_like_count
} 12

# No GLOB optimization without an index.
#
do_test like-3.17 {
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t1 WHERE x GLOB 'abc*' ORDER BY 1;
  }
} {abc abcd sort t1 *}
do_test like-3.18 {
  set sqlite_like_count
} 12

# GLOB is optimized regardless of the case_sensitive_like setting.
#
do_test like-3.19 {
  set sqlite_like_count 0
  db eval {CREATE INDEX i1 ON t1(x);}
  queryplan {
    SELECT x FROM t1 WHERE x GLOB 'abc*' ORDER BY 1;
  }
} {abc abcd nosort {} i1}
do_test like-3.20 {
  set sqlite_like_count
} 0
do_test like-3.21 {
  set sqlite_like_count 0
  db eval {PRAGMA case_sensitive_like=on;}
  queryplan {
    SELECT x FROM t1 WHERE x GLOB 'abc*' ORDER BY 1;
  }
} {abc abcd nosort {} i1}
do_test like-3.22 {
  set sqlite_like_count
} 0
do_test like-3.23 {
  set sqlite_like_count 0
  db eval {PRAGMA case_sensitive_like=off;}
  queryplan {
    SELECT x FROM t1 WHERE x GLOB 'a[bc]d' ORDER BY 1;
  }
} {abd acd nosort {} i1}
do_test like-3.24 {
  set sqlite_like_count
} 6

# GLOB optimization when there is no wildcard.  Ticket [e090183531fc2747]
#
do_test like-3.25 {
  queryplan {
    SELECT x FROM t1 WHERE x GLOB 'a' ORDER BY 1;
  }
} {a nosort {} i1}
do_test like-3.26 {
  queryplan {
    SELECT x FROM t1 WHERE x GLOB 'abcd' ORDER BY 1;
  }
} {abcd nosort {} i1}
do_test like-3.27 {
  queryplan {
    SELECT x FROM t1 WHERE x GLOB 'abcde' ORDER BY 1;
  }
} {nosort {} i1}



# No optimization if the LHS of the LIKE is not a column name or
# if the RHS is not a string.
#
do_test like-4.1 {
  execsql {PRAGMA case_sensitive_like=on}
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t1 WHERE x LIKE 'abc%' ORDER BY 1
  }
} {abc abcd nosort {} i1}
do_test like-4.2 {
  set sqlite_like_count
} 0
do_test like-4.3 {
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t1 WHERE +x LIKE 'abc%' ORDER BY 1
  }
} {abc abcd nosort {} i1}
do_test like-4.4 {
  set sqlite_like_count
} 12
do_test like-4.5 {
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t1 WHERE x LIKE ('ab' || 'c%') ORDER BY 1
  }
} {abc abcd nosort {} i1}
do_test like-4.6 {
  set sqlite_like_count
} 12

# Collating sequences on the index disable the LIKE optimization.
# Or if the NOCASE collating sequence is used, the LIKE optimization
# is enabled when case_sensitive_like is OFF.
#
do_test like-5.1 {
  execsql {PRAGMA case_sensitive_like=off}
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t1 WHERE x LIKE 'abc%' ORDER BY 1
  }
} {ABC {ABC abc xyz} abc abcd nosort {} i1}
do_test like-5.2 {
  set sqlite_like_count
} 12
do_test like-5.3 {
  execsql {
    CREATE TABLE t2(x TEXT COLLATE NOCASE PRIMARY KEY);
    INSERT INTO t2 SELECT * FROM t1;
    CREATE INDEX i2 ON t2(x COLLATE NOCASE);
  }
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t2 WHERE x LIKE 'abc%' ORDER BY 1
  }
} {abc ABC {ABC abc xyz} abcd nosort {} i2}
do_test like-5.4 {
  set sqlite_like_count
} 0
do_test like-5.5 {
  execsql {
    PRAGMA case_sensitive_like=on;
  }
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t2 WHERE x LIKE 'abc%' ORDER BY 1
  }
} {abc abcd nosort {} i2}
do_test like-5.6 {
  set sqlite_like_count
} 12
do_test like-5.7 {
  execsql {
    PRAGMA case_sensitive_like=off;
  }
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t2 WHERE x GLOB 'abc*' ORDER BY 1
  }
} {abc abcd nosort {} i2}
do_test like-5.8 {
  set sqlite_like_count
} 12
do_test like-5.11 {
  execsql {PRAGMA case_sensitive_like=off}
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t1 WHERE x LIKE 'ABC%' ORDER BY 1
  }
} {ABC {ABC abc xyz} abc abcd nosort {} i1}
do_test like-5.12 {
  set sqlite_like_count
} 12
do_test like-5.13 {
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t2 WHERE x LIKE 'ABC%' ORDER BY 1
  }
} {abc ABC {ABC abc xyz} abcd nosort {} i2}
do_test like-5.14 {
  set sqlite_like_count
} 0
do_test like-5.15 {
  execsql {
    PRAGMA case_sensitive_like=on;
  }
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t2 WHERE x LIKE 'ABC%' ORDER BY 1
  }
} {ABC {ABC abc xyz} nosort {} i2}
do_test like-5.16 {
  set sqlite_like_count
} 12
do_test like-5.17 {
  execsql {
    PRAGMA case_sensitive_like=off;
  }
  set sqlite_like_count 0
  queryplan {
    SELECT x FROM t2 WHERE x GLOB 'ABC*' ORDER BY 1
  }
} {ABC {ABC abc xyz} nosort {} i2}
do_test like-5.18 {
  set sqlite_like_count
} 12

# Boundary case.  The prefix for a LIKE comparison is rounded up
# when constructing the comparison.  Example:  "ab" becomes "ac".
# In other words, the last character is increased by one.
#
# Make sure this happens correctly when the last character is a 
# "z" and we are doing case-insensitive comparisons.
#
# Ticket #2959
#
do_test like-5.21 {
  execsql {
    PRAGMA case_sensitive_like=off;
    INSERT INTO t2 VALUES('ZZ-upper-upper');
    INSERT INTO t2 VALUES('zZ-lower-upper');
    INSERT INTO t2 VALUES('Zz-upper-lower');
    INSERT INTO t2 VALUES('zz-lower-lower');
  }
  queryplan {
    SELECT x FROM t2 WHERE x LIKE 'zz%';
  }
} {zz-lower-lower zZ-lower-upper Zz-upper-lower ZZ-upper-upper nosort {} i2}
do_test like-5.22 {
  queryplan {
    SELECT x FROM t2 WHERE x LIKE 'zZ%';
  }
} {zz-lower-lower zZ-lower-upper Zz-upper-lower ZZ-upper-upper nosort {} i2}
do_test like-5.23 {
  queryplan {
    SELECT x FROM t2 WHERE x LIKE 'Zz%';
  }
} {zz-lower-lower zZ-lower-upper Zz-upper-lower ZZ-upper-upper nosort {} i2}
do_test like-5.24 {
  queryplan {
    SELECT x FROM t2 WHERE x LIKE 'ZZ%';
  }
} {zz-lower-lower zZ-lower-upper Zz-upper-lower ZZ-upper-upper nosort {} i2}
do_test like-5.25 {
  db eval {
    PRAGMA case_sensitive_like=on;
    CREATE TABLE t3(id primary key, x TEXT);
    CREATE INDEX i3 ON t3(x);
    INSERT INTO t3 VALUES(1, 'ZZ-upper-upper');
    INSERT INTO t3 VALUES(2, 'zZ-lower-upper');
    INSERT INTO t3 VALUES(3, 'Zz-upper-lower');
    INSERT INTO t3 VALUES(4, 'zz-lower-lower');
  }
  queryplan {
    SELECT x FROM t3 WHERE x LIKE 'zz%';
  }
} {zz-lower-lower nosort {} i3}
do_test like-5.26 {
  queryplan {
    SELECT x FROM t3 WHERE x LIKE 'zZ%';
  }
} {zZ-lower-upper nosort {} i3}
do_test like-5.27 {
  queryplan {
    SELECT x FROM t3 WHERE x LIKE 'Zz%';
  }
} {Zz-upper-lower nosort {} i3}
do_test like-5.28 {
  queryplan {
    SELECT x FROM t3 WHERE x LIKE 'ZZ%';
  }
} {ZZ-upper-upper nosort {} i3}


# ticket #2407
#
# Make sure the LIKE prefix optimization does not strip off leading
# characters of the like pattern that happen to be quote characters.
#
do_test like-6.1 {
  foreach x { 'abc 'bcd 'def 'ax } {
    set x2 '[string map {' ''} $x]'
    db eval "INSERT INTO t2 VALUES($x2)"
  }
  execsql {
    SELECT * FROM t2 WHERE x LIKE '''a%'
  }
} {'abc 'ax}

# do_test like-7.1 {
#   execsql {
#     SELECT rowid, * FROM t1 WHERE rowid GLOB '1*' ORDER BY rowid;
#   }
# } {1 a 10 ABC 11 CDE 12 {ABC abc xyz}}

# ticket #3345.
#
# Overloading the LIKE function with -1 for the number of arguments
# will overload both the 2-argument and the 3-argument LIKE.
#
do_test like-8.1 {
  db eval {
    CREATE TABLE t8(x primary key);
    INSERT INTO t8 VALUES('abcdef');
    INSERT INTO t8 VALUES('ghijkl');
    INSERT INTO t8 VALUES('mnopqr');
    SELECT 1, x FROM t8 WHERE x LIKE '%h%';
    SELECT 2, x FROM t8 WHERE x LIKE '%h%' ESCAPE 'x';
  }
} {1 ghijkl 2 ghijkl}
do_test like-8.2 {
  proc newlike {args} {return 1} ;# Alternative LIKE is always return TRUE
  db function like newlike       ;# Uses -1 for nArg in sqlite3_create_function
  db cache flush
  db eval {
    SELECT 1, x FROM t8 WHERE x LIKE '%h%';
    SELECT 2, x FROM t8 WHERE x LIKE '%h%' ESCAPE 'x';
  }
} {1 ghijkl 2 ghijkl}
do_test like-8.3 {
  db function like -argcount 2 newlike
  db eval {
    SELECT 1, x FROM t8 WHERE x LIKE '%h%';
    SELECT 2, x FROM t8 WHERE x LIKE '%h%' ESCAPE 'x';
  }
} {1 abcdef 1 ghijkl 1 mnopqr 2 ghijkl}
do_test like-8.4 {
  db function like -argcount 3 newlike
  db eval {
    SELECT 1, x FROM t8 WHERE x LIKE '%h%';
    SELECT 2, x FROM t8 WHERE x LIKE '%h%' ESCAPE 'x';
  }
} {1 abcdef 1 ghijkl 1 mnopqr 2 abcdef 2 ghijkl 2 mnopqr}


ifcapable like_opt&&!icu {
  # Evaluate SQL.  Return the result set followed by the
  # and the number of full-scan steps.
  #
  db close
  sqlite3 db test.db
  proc count_steps {sql} {
    set r [db eval $sql]
    lappend r scan [db status step] sort [db status sort]
  }
  do_test like-9.1 {
    count_steps {
       SELECT x FROM t2 WHERE x LIKE 'x%'
    }
  } {xyz scan 0 sort 0}
  do_test like-9.2 {
    count_steps {
       SELECT x FROM t2 WHERE x LIKE '_y%'
    }
  } {xyz scan 19 sort 0}
  do_test like-9.3.1 {
    set res [sqlite3_exec_hex db {
       SELECT x FROM t2 WHERE x LIKE '%78%25'
    }]
  } {0 {x xyz}}
  ifcapable explain {
    do_test like-9.3.2 {
      set res [sqlite3_exec_hex db {
         EXPLAIN QUERY PLAN SELECT x FROM t2 WHERE x LIKE '%78%25'
      }]
      regexp {INDEX i2} $res
    } {1}
  }
  do_test like-9.4.1 {
    sqlite3_exec_hex db {INSERT INTO t2 VALUES('%ffhello')}
    set res [sqlite3_exec_hex db {
       SELECT substr(x,2) AS x FROM t2 WHERE +x LIKE '%ff%25'
    }]
  } {0 {x hello}}
  do_test like-9.4.2 {
    set res [sqlite3_exec_hex db {
       SELECT substr(x,2) AS x FROM t2 WHERE x LIKE '%ff%25'
    }]
  } {0 {x hello}}
  ifcapable explain {
    do_test like-9.4.3 {
      set res [sqlite3_exec_hex db {
         EXPLAIN QUERY PLAN SELECT x FROM t2 WHERE x LIKE '%ff%25'
      }]
      regexp {SCAN TABLE t2} $res
    } {1}
  }
  do_test like-9.5.1 {
    set res [sqlite3_exec_hex db {
       SELECT x FROM t2 WHERE x LIKE '%fe%25'
    }]
  } {0 {}}
  ifcapable explain {
    do_test like-9.5.2 {
      set res [sqlite3_exec_hex db {
         EXPLAIN QUERY PLAN SELECT x FROM t2 WHERE x LIKE '%fe%25'
      }]
      regexp {INDEX i2} $res
    } {1}
  }

  # Do an SQL statement.  Append the search count to the end of the result.
  #
  proc count sql {
    set ::sqlite_search_count 0
    set ::sqlite_like_count 0
    return [concat [execsql $sql] scan $::sqlite_search_count \
             like $::sqlite_like_count]
  }

  # The LIKE and GLOB optimizations do not work on columns with
  # affinity other than TEXT.
  # Ticket #3901
  #
  do_test like-10.1 {
    db close
    sqlite3 db test.db
    execsql {
      CREATE TABLE t10(
        a INTEGER PRIMARY KEY,
        b INTEGER COLLATE nocase UNIQUE,
        c NUMBER COLLATE nocase UNIQUE,
        d BLOB COLLATE nocase UNIQUE,
        e COLLATE nocase UNIQUE,
        f TEXT COLLATE nocase UNIQUE
      );
      INSERT INTO t10 VALUES(1,1,1,1,1,1);
      INSERT INTO t10 VALUES(12,12,12,12,12,12);
      INSERT INTO t10 VALUES(123,123,123,123,123,123);
      INSERT INTO t10 VALUES(234,234,234,234,234,234);
      INSERT INTO t10 VALUES(345,345,345,345,345,345);
      INSERT INTO t10 VALUES(45,45,45,45,45,45);
    }
    count {
      SELECT a FROM t10 WHERE b LIKE '12%' ORDER BY +a;
    }
  } {12 123 scan 5 like 6}
  do_test like-10.2 {
    count {
      SELECT a FROM t10 WHERE c LIKE '12%' ORDER BY +a;
    }
  } {12 123 scan 5 like 6}
  do_test like-10.3 {
    count {
      SELECT a FROM t10 WHERE d LIKE '12%' ORDER BY +a;
    }
  } {12 123 scan 5 like 6}
  do_test like-10.4 {
    count {
      SELECT a FROM t10 WHERE e LIKE '12%' ORDER BY +a;
    }
  } {12 123 scan 5 like 6}
  do_test like-10.5 {
    count {
      SELECT a FROM t10 WHERE f LIKE '12%' ORDER BY +a;
    }
  } {12 123 scan 4 like 0}
  do_test like-10.6 {
    count {
      SELECT a FROM t10 WHERE a LIKE '12%' ORDER BY +a;
    }
  } {12 123 scan 5 like 6}
  do_test like-10.10 {
    execsql {
      CREATE TABLE t10b(
        a INTEGER PRIMARY KEY,
        b INTEGER UNIQUE,
        c NUMBER UNIQUE,
        d BLOB UNIQUE,
        e UNIQUE,
        f TEXT UNIQUE
      );
      INSERT INTO t10b SELECT * FROM t10;
    }
    count {
      SELECT a FROM t10b WHERE b GLOB '12*' ORDER BY +a;
    }
  } {12 123 scan 5 like 6}
  do_test like-10.11 {
    count {
      SELECT a FROM t10b WHERE c GLOB '12*' ORDER BY +a;
    }
  } {12 123 scan 5 like 6}
  do_test like-10.12 {
    count {
      SELECT a FROM t10b WHERE d GLOB '12*' ORDER BY +a;
    }
  } {12 123 scan 5 like 6}
  do_test like-10.13 {
    count {
      SELECT a FROM t10b WHERE e GLOB '12*' ORDER BY +a;
    }
  } {12 123 scan 5 like 6}
  do_test like-10.14 {
    count {
      SELECT a FROM t10b WHERE f GLOB '12*' ORDER BY +a;
    }
  } {12 123 scan 4 like 0}
  do_test like-10.15 {
    count {
      SELECT a FROM t10b WHERE a GLOB '12*' ORDER BY +a;
    }
  } {12 123 scan 5 like 6}
}

# LIKE and GLOB where the default collating sequence is not appropriate
# but an index with the appropriate collating sequence exists.
#
do_test like-11.0 {
  execsql {
    CREATE TABLE t11(
      a INTEGER PRIMARY KEY,
      b TEXT COLLATE nocase,
      c TEXT COLLATE binary
    );
    INSERT INTO t11 VALUES(1, 'a','a');
    INSERT INTO t11 VALUES(2, 'ab','ab');
    INSERT INTO t11 VALUES(3, 'abc','abc');
    INSERT INTO t11 VALUES(4, 'abcd','abcd');
    INSERT INTO t11 VALUES(5, 'A','A');
    INSERT INTO t11 VALUES(6, 'AB','AB');
    INSERT INTO t11 VALUES(7, 'ABC','ABC');
    INSERT INTO t11 VALUES(8, 'ABCD','ABCD');
    INSERT INTO t11 VALUES(9, 'x','x');
    INSERT INTO t11 VALUES(10, 'yz','yz');
    INSERT INTO t11 VALUES(11, 'X','X');
    INSERT INTO t11 VALUES(12, 'YZ','YZ');
    SELECT count(*) FROM t11;
  }
} {12}
do_test like-11.1 {
  db eval {PRAGMA case_sensitive_like=OFF;}
  queryplan {
    SELECT b FROM t11 WHERE b LIKE 'abc%' ORDER BY a;
  }
} {abc abcd ABC ABCD nosort t11 *}
do_test like-11.2 {
  db eval {PRAGMA case_sensitive_like=ON;}
  queryplan {
    SELECT b FROM t11 WHERE b LIKE 'abc%' ORDER BY a;
  }
} {abc abcd nosort t11 *}
do_test like-11.3 {
  db eval {
    PRAGMA case_sensitive_like=OFF;
    CREATE INDEX t11b ON t11(b);
  }
  queryplan {
    SELECT b FROM t11 WHERE b LIKE 'abc%' ORDER BY +a;
  }
} {abc abcd ABC ABCD sort {} t11b}
do_test like-11.4 {
  db eval {PRAGMA case_sensitive_like=ON;}
  queryplan {
    SELECT b FROM t11 WHERE b LIKE 'abc%' ORDER BY a;
  }
} {abc abcd nosort t11 *}

do_test like-11.5 {
  db eval {
    PRAGMA case_sensitive_like=OFF;
    DROP INDEX '547_1_t11b';
    CREATE INDEX t11bnc ON t11(b COLLATE nocase);
  }
  queryplan {
    SELECT b FROM t11 WHERE b LIKE 'abc%' ORDER BY +a;
  }
} {abc abcd ABC ABCD sort {} t11bnc}
do_test like-11.6 {
  db eval {CREATE INDEX t11bb ON t11(b COLLATE binary);}
  queryplan {
    SELECT b FROM t11 WHERE b LIKE 'abc%' ORDER BY +a;
  }
} {abc abcd ABC ABCD sort {} t11bnc}
do_test like-11.7 {
  db eval {PRAGMA case_sensitive_like=ON;}
  queryplan {
    SELECT b FROM t11 WHERE b LIKE 'abc%' ORDER BY +a;
  }
} {abc abcd sort {} t11bb}
do_test like-11.8 {
  db eval {PRAGMA case_sensitive_like=OFF;}
  queryplan {
    SELECT b FROM t11 WHERE b GLOB 'abc*' ORDER BY +a;
  }
} {abc abcd sort {} t11bb}
do_test like-11.9 {
  db eval {
    CREATE INDEX t11cnc ON t11(c COLLATE nocase);
    CREATE INDEX t11cb ON t11(c COLLATE binary);
  }
  queryplan {
    SELECT c FROM t11 WHERE c LIKE 'abc%' ORDER BY +a;
  }
} {abc abcd ABC ABCD sort {} t11cnc}
do_test like-11.10 {
  queryplan {
    SELECT c FROM t11 WHERE c GLOB 'abc*' ORDER BY +a;
  }
} {abc abcd sort {} t11cb}

# A COLLATE clause on the pattern does not change the result of a
# LIKE operator.
#
do_execsql_test like-12.1 {
  CREATE TABLE t12nc(id INTEGER PRIMARY KEY, x TEXT UNIQUE COLLATE nocase);
  INSERT INTO t12nc VALUES(1,'abcde'),(2,'uvwxy'),(3,'ABCDEF');
  CREATE TABLE t12b(id INTEGER PRIMARY KEY, x TEXT UNIQUE COLLATE binary);
  INSERT INTO t12b VALUES(1,'abcde'),(2,'uvwxy'),(3,'ABCDEF');
  SELECT id FROM t12nc WHERE x LIKE 'abc%' ORDER BY +id;
} {1 3}
do_execsql_test like-12.2 {
  SELECT id FROM t12b WHERE x LIKE 'abc%' ORDER BY +id;
} {1 3}
do_execsql_test like-12.3 {
  SELECT id FROM t12nc WHERE x LIKE 'abc%' COLLATE binary ORDER BY +id;
} {1 3}
do_execsql_test like-12.4 {
  SELECT id FROM t12b WHERE x LIKE 'abc%' COLLATE binary ORDER BY +id;
} {1 3}
do_execsql_test like-12.5 {
  SELECT id FROM t12nc WHERE x LIKE 'abc%' COLLATE nocase ORDER BY +id;
} {1 3}
do_execsql_test like-12.6 {
  SELECT id FROM t12b WHERE x LIKE 'abc%' COLLATE nocase ORDER BY +id;
} {1 3}

# Adding a COLLATE clause to the pattern of a LIKE operator does nothing
# to change the suitability of using an index to satisfy that LIKE
# operator.
#
do_execsql_test like-12.11 {
  EXPLAIN QUERY PLAN
  SELECT id FROM t12nc WHERE x LIKE 'abc%' ORDER BY +id;
} {/SEARCH/}
do_execsql_test like-12.12 {
  EXPLAIN QUERY PLAN
  SELECT id FROM t12b WHERE x LIKE 'abc%' ORDER BY +id;
} {/SCAN/}
do_execsql_test like-12.13 {
  EXPLAIN QUERY PLAN
  SELECT id FROM t12nc WHERE x LIKE 'abc%' COLLATE nocase ORDER BY +id;
} {/SEARCH/}
do_execsql_test like-12.14 {
  EXPLAIN QUERY PLAN
  SELECT id FROM t12b WHERE x LIKE 'abc%' COLLATE nocase ORDER BY +id;
} {/SCAN/}
do_execsql_test like-12.15 {
  EXPLAIN QUERY PLAN
  SELECT id FROM t12nc WHERE x LIKE 'abc%' COLLATE binary ORDER BY +id;
} {/SEARCH/}
do_execsql_test like-12.16 {
  EXPLAIN QUERY PLAN
  SELECT id FROM t12b WHERE x LIKE 'abc%' COLLATE binary ORDER BY +id;
} {/SCAN/}


finish_test
