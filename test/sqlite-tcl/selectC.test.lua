#!./tcltestrunner.lua

# 2008 September 16
#
# The author disclaims copyright to this source code.  In place of
# a legal notice, here is a blessing:
#
#    May you do good and not evil.
#    May you find forgiveness for yourself and forgive others.
#    May you share freely, never taking more than you give.
#
#***********************************************************************
# This file implements regression tests for SQLite library. 
#
# $Id: selectC.test,v 1.5 2009/05/17 15:26:21 drh Exp $

set testdir [file dirname $argv0]
source $testdir/tester.tcl

# Ticket #
do_test selectC-1.1 {
  execsql {
    DROP TABLE IF EXISTS t1;
    CREATE TABLE t1(id PRIMARY KEY, a, b, c);
    INSERT INTO t1 VALUES(1, 1,'aaa','bbb');
    INSERT INTO t1 VALUES(2, 1, 'aaa', 'bbb');
    INSERT INTO t1 VALUES(3, 2,'ccc','ddd');

    SELECT DISTINCT a AS x, b||c AS y
      FROM t1
     WHERE y IN ('aaabbb','xxx');
  }
} {1 aaabbb}
do_test selectC-1.2 {
  execsql {
    SELECT DISTINCT a AS x, b||c AS y
      FROM t1
     WHERE b||c IN ('aaabbb','xxx');
  }
} {1 aaabbb}
do_test selectC-1.3 {
  execsql {
    SELECT DISTINCT a AS x, b||c AS y
      FROM t1
     WHERE y='aaabbb'
  }
} {1 aaabbb}
do_test selectC-1.4 {
  execsql {
    SELECT DISTINCT a AS x, b||c AS y
      FROM t1
     WHERE b||c='aaabbb'
  }
} {1 aaabbb}
do_test selectC-1.5 {
  execsql {
    SELECT DISTINCT a AS x, b||c AS y
      FROM t1
     WHERE x=2
  }
} {2 cccddd}
do_test selectC-1.6 {
  execsql {
    SELECT DISTINCT a AS x, b||c AS y
      FROM t1
     WHERE a=2
  }
} {2 cccddd}
do_test selectC-1.7 {
  execsql {
    SELECT DISTINCT a AS x, b||c AS y
      FROM t1
     WHERE +y='aaabbb'
  }
} {1 aaabbb}
do_test selectC-1.8 {
  execsql {
    SELECT a AS x, b||c AS y
      FROM t1
     GROUP BY x, y
    HAVING y='aaabbb'
  }
} {1 aaabbb}
do_test selectC-1.9 {
  execsql {
    SELECT a AS x, b||c AS y
      FROM t1
     GROUP BY x, y
    HAVING b||c='aaabbb'
  }
} {1 aaabbb}
do_test selectC-1.10 {
  execsql {
    SELECT a AS x, b||c AS y
      FROM t1
     WHERE y='aaabbb'
     GROUP BY x, y
  }
} {1 aaabbb}
do_test selectC-1.11 {
  execsql {
    SELECT a AS x, b||c AS y
      FROM t1
     WHERE b||c='aaabbb'
     GROUP BY x, y
  }
} {1 aaabbb}
proc longname_toupper x {return [string toupper $x]}
db function uppercaseconversionfunctionwithaverylongname longname_toupper
do_test selectC-1.12.1 {
  execsql {
    SELECT DISTINCT upper(b) AS x
      FROM t1
     ORDER BY x
  }
} {AAA CCC}
do_test selectC-1.12.2 {
  execsql {
    SELECT DISTINCT uppercaseconversionfunctionwithaverylongname(b) AS x
      FROM t1
     ORDER BY x
  }
} {AAA CCC}
do_test selectC-1.13.1 {
  execsql {
    SELECT upper(b) AS x
      FROM t1
     GROUP BY x
     ORDER BY x
  }
} {AAA CCC}
do_test selectC-1.13.2 {
  execsql {
    SELECT uppercaseconversionfunctionwithaverylongname(b) AS x
      FROM t1
     GROUP BY x
     ORDER BY x
  }
} {AAA CCC}
do_test selectC-1.14.1 {
  execsql {
    SELECT upper(b) AS x
      FROM t1
     ORDER BY x DESC
  }
} {CCC AAA AAA}
do_test selectC-1.14.2 {
  execsql {
    SELECT uppercaseconversionfunctionwithaverylongname(b) AS x
      FROM t1
     ORDER BY x DESC
  }
} {CCC AAA AAA}

# MUST_WORK_TEST

# # The following query used to leak memory.  Verify that has been fixed.
# #
# ifcapable trigger&&compound {
#   do_test selectC-2.1 {
#     catchsql {
#       CREATE TABLE t21a(a,b);
#       INSERT INTO t21a VALUES(1,2);
#       CREATE TABLE t21b(n);
#       CREATE TRIGGER r21 AFTER INSERT ON t21b BEGIN
#         SELECT a FROM t21a WHERE a>new.x UNION ALL
#         SELECT b FROM t21a WHERE b>new.x ORDER BY 1 LIMIT 2;
#       END;
#       INSERT INTO t21b VALUES(6);
#     }
#   } {1 {no such column: new.x}}
# }

# MUST_WORK_TEST

# # Check that ticket [883034dcb5] is fixed.
# #
# do_test selectC-3.1 {
#   execsql {
#     DROP TABLE IF EXISTS person;
#     CREATE TABLE person (
#         org_id          TEXT NOT NULL,
#         nickname        TEXT NOT NULL,
#         license         TEXT,
#         CONSTRAINT person_pk PRIMARY KEY (org_id, nickname),
#         CONSTRAINT person_license_uk UNIQUE (license)
#     );
#     INSERT INTO person VALUES('meyers', 'jack', '2GAT123');
#     INSERT INTO person VALUES('meyers', 'hill', 'V345FMP');
#     INSERT INTO person VALUES('meyers', 'jim', '2GAT138');
#     INSERT INTO person VALUES('smith', 'maggy', '');
#     INSERT INTO person VALUES('smith', 'jose', 'JJZ109');
#     INSERT INTO person VALUES('smith', 'jack', 'THX138');
#     INSERT INTO person VALUES('lakeside', 'dave', '953OKG');
#     INSERT INTO person VALUES('lakeside', 'amy', NULL);
#     INSERT INTO person VALUES('lake-apts', 'tom', NULL);
#     INSERT INTO person VALUES('acorn', 'hideo', 'CQB421');
    
#     SELECT 
#       org_id, 
#       count((NOT (org_id IS NULL)) AND (NOT (nickname IS NULL)))
#     FROM person 
#     WHERE (CASE WHEN license != '' THEN 1 ELSE 0 END)
#     GROUP BY 1;
#   }
# } {acorn 1 lakeside 1 meyers 3 smith 2}
do_test selectC-3.2 {
  execsql {
    DROP TABLE IF EXISTS t2;
    CREATE TABLE t2(a PRIMARY KEY, b);
    INSERT INTO t2 VALUES('abc', 'xxx');
    INSERT INTO t2 VALUES('def', 'yyy');
    SELECT a, max(b || a) FROM t2 WHERE (b||b||b)!='value' GROUP BY a;
  }
} {abc xxxabc def yyydef}
do_test selectC-3.3 {
  execsql {
    SELECT b, max(a || b) FROM t2 WHERE (b||b||b)!='value' GROUP BY a;
  }
} {xxx abcxxx yyy defyyy}


proc udf {} { incr ::udf }
set ::udf 0
db function udf udf

do_execsql_test selectC-4.1 {
  create table t_distinct_bug (id int primary key, a, b, c);
  insert into t_distinct_bug values (0, '1', '1', 'a');
  insert into t_distinct_bug values (1, '1', '2', 'b');
  insert into t_distinct_bug values (2, '1', '3', 'c');
  insert into t_distinct_bug values (3, '1', '1', 'd');
  insert into t_distinct_bug values (4, '1', '2', 'e');
  insert into t_distinct_bug values (5, '1', '3', 'f');
} {}

do_execsql_test selectC-4.2 {
  select a from (select distinct a, b from t_distinct_bug)
} {1 1 1}

do_execsql_test selectC-4.3 {
  select a, udf() from (select distinct a, b from t_distinct_bug)
} {1 1 1 2 1 3}

finish_test
