#!./tcltestrunner.lua

# 2001 September 15
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
# focus of this file is testing built-in functions.
#

set testdir [file dirname $argv0]
source $testdir/tester.tcl
set testprefix func

# Create a table to work with.
#
do_test func-0.0 {
  execsql {CREATE TABLE tbl1(id integer primary key, t1 text)}
  set i 1
  foreach word {this program is free software} {
    execsql "INSERT INTO tbl1(id, t1) VALUES($i, '$word')"
    incr i
  }
  execsql {SELECT t1 FROM tbl1 ORDER BY t1}
} {free is program software this}
do_test func-0.1 {
  execsql {
     CREATE TABLE t2(id integer primary key, a);
     INSERT INTO t2(id,a) VALUES(1, 1);
     INSERT INTO t2(id,a) VALUES(2, NULL);
     INSERT INTO t2(id,a) VALUES(3, 345);
     INSERT INTO t2(id,a) VALUES(4, NULL);
     INSERT INTO t2(id,a) VALUES(5, 67890);
     SELECT a FROM t2;
  }
} {1 {} 345 {} 67890}

# Check out the length() function
#
do_test func-1.0 {
  execsql {SELECT length(t1) FROM tbl1 ORDER BY t1}
} {4 2 7 8 4}
do_test func-1.1 {
  set r [catch {execsql {SELECT length(*) FROM tbl1 ORDER BY t1}} msg]
  lappend r $msg
} {1 {wrong number of arguments to function length()}}
do_test func-1.2 {
  set r [catch {execsql {SELECT length(t1,5) FROM tbl1 ORDER BY t1}} msg]
  lappend r $msg
} {1 {wrong number of arguments to function length()}}
do_test func-1.3 {
  execsql {SELECT length(t1), count(t1) FROM tbl1 GROUP BY length(t1)
           ORDER BY length(t1)}
} {2 1 4 2 7 1 8 1}
do_test func-1.4 {
  execsql {SELECT coalesce(length(a),-1) FROM t2}
} {1 -1 3 -1 5}

# Check out the substr() function
#
do_test func-2.0 {
  execsql {SELECT substr(t1,1,2) FROM tbl1 ORDER BY t1}
} {fr is pr so th}
do_test func-2.1 {
  execsql {SELECT substr(t1,2,1) FROM tbl1 ORDER BY t1}
} {r s r o h}
do_test func-2.2 {
  execsql {SELECT substr(t1,3,3) FROM tbl1 ORDER BY t1}
} {ee {} ogr ftw is}
do_test func-2.3 {
  execsql {SELECT substr(t1,-1,1) FROM tbl1 ORDER BY t1}
} {e s m e s}
do_test func-2.4 {
  execsql {SELECT substr(t1,-1,2) FROM tbl1 ORDER BY t1}
} {e s m e s}
do_test func-2.5 {
  execsql {SELECT substr(t1,-2,1) FROM tbl1 ORDER BY t1}
} {e i a r i}
do_test func-2.6 {
  execsql {SELECT substr(t1,-2,2) FROM tbl1 ORDER BY t1}
} {ee is am re is}
do_test func-2.7 {
  execsql {SELECT substr(t1,-4,2) FROM tbl1 ORDER BY t1}
} {fr {} gr wa th}
do_test func-2.8 {
  execsql {SELECT t1 FROM tbl1 ORDER BY substr(t1,2,20)}
} {this software free program is}
do_test func-2.9 {
  execsql {SELECT substr(a,1,1) FROM t2}
} {1 {} 3 {} 6}
do_test func-2.10 {
  execsql {SELECT substr(a,2,2) FROM t2}
} {{} {} 45 {} 78}

# Only do the following tests if TCL has UTF-8 capabilities
#
if {"\u1234"!="u1234"} {

# Put some UTF-8 characters in the database
#
do_test func-3.0 {
  execsql {DELETE FROM tbl1}
  set i 1
  foreach word "contains UTF-8 characters hi\u1234ho" {
    execsql "INSERT INTO tbl1(id, t1) VALUES($i, '$word')"
    incr i
  }
  execsql {SELECT t1 FROM tbl1 ORDER BY t1}
} "UTF-8 characters contains hi\u1234ho"
do_test func-3.1 {
  execsql {SELECT length(t1) FROM tbl1 ORDER BY t1}
} {5 10 8 5}
do_test func-3.2 {
  execsql {SELECT substr(t1,1,2) FROM tbl1 ORDER BY t1}
} {UT ch co hi}
do_test func-3.3 {
  execsql {SELECT substr(t1,1,3) FROM tbl1 ORDER BY t1}
} "UTF cha con hi\u1234"
do_test func-3.4 {
  execsql {SELECT substr(t1,2,2) FROM tbl1 ORDER BY t1}
} "TF ha on i\u1234"
do_test func-3.5 {
  execsql {SELECT substr(t1,2,3) FROM tbl1 ORDER BY t1}
} "TF- har ont i\u1234h"
do_test func-3.6 {
  execsql {SELECT substr(t1,3,2) FROM tbl1 ORDER BY t1}
} "F- ar nt \u1234h"
do_test func-3.7 {
  execsql {SELECT substr(t1,4,2) FROM tbl1 ORDER BY t1}
} "-8 ra ta ho"
do_test func-3.8 {
  execsql {SELECT substr(t1,-1,1) FROM tbl1 ORDER BY t1}
} "8 s s o"
do_test func-3.9 {
  execsql {SELECT substr(t1,-3,2) FROM tbl1 ORDER BY t1}
} "F- er in \u1234h"
do_test func-3.10 {
  execsql {SELECT substr(t1,-4,3) FROM tbl1 ORDER BY t1}
} "TF- ter ain i\u1234h"
do_test func-3.99 {
  execsql {DELETE FROM tbl1}
  set i 1
  foreach word {this program is free software} {
    execsql "INSERT INTO tbl1(id, t1) VALUES($i, '$word')"
    incr i
  }
  execsql {SELECT t1 FROM tbl1}
} {this program is free software}

} ;# End \u1234!=u1234

# Test the abs() and round() functions.
#
ifcapable !floatingpoint {
  do_test func-4.1 {
    execsql {
      CREATE TABLE t1(id integer primary key, a,b,c);
      INSERT INTO t1(id, a,b,c) VALUES(1, 1,2,3);
      INSERT INTO t1(id, a,b,c) VALUES(2, 2,12345678901234,-1234567890);
      INSERT INTO t1(id, a,b,c) VALUES(3, 3,-2,-5);
    }
    catchsql {SELECT abs(a,b) FROM t1}
  } {1 {wrong number of arguments to function abs()}}
}
ifcapable floatingpoint {
  do_test func-4.1 {
    execsql {
      CREATE TABLE t1(id integer primary key, a,b,c);
      INSERT INTO t1(id, a,b,c) VALUES(1, 1,2,3);
      INSERT INTO t1(id, a,b,c) VALUES(2, 2,1.2345678901234,-12345.67890);
      INSERT INTO t1(id, a,b,c) VALUES(3, 3,-2,-5);
    }
    catchsql {SELECT abs(a,b) FROM t1}
  } {1 {wrong number of arguments to function abs()}}
}
do_test func-4.2 {
  catchsql {SELECT abs() FROM t1}
} {1 {wrong number of arguments to function abs()}}
ifcapable floatingpoint {
  do_test func-4.3 {
    catchsql {SELECT abs(b) FROM t1 ORDER BY a}
  } {0 {2 1.2345678901234 2}}
  do_test func-4.4 {
    catchsql {SELECT abs(c) FROM t1 ORDER BY a}
  } {0 {3 12345.6789 5}}
}
ifcapable !floatingpoint {
  if {[working_64bit_int]} {
    do_test func-4.3 {
      catchsql {SELECT abs(b) FROM t1 ORDER BY a}
    } {0 {2 12345678901234 2}}
  }
  do_test func-4.4 {
    catchsql {SELECT abs(c) FROM t1 ORDER BY a}
  } {0 {3 1234567890 5}}
}
do_test func-4.4.1 {
  execsql {SELECT abs(a) FROM t2}
} {1 {} 345 {} 67890}
do_test func-4.4.2 {
  execsql {SELECT abs(t1) FROM tbl1}
} {0.0 0.0 0.0 0.0 0.0}

ifcapable floatingpoint {
  do_test func-4.5 {
    catchsql {SELECT round(a,b,c) FROM t1}
  } {1 {wrong number of arguments to function round()}}
  do_test func-4.6 {
    catchsql {SELECT round(b,2) FROM t1 ORDER BY b}
  } {0 {-2.0 1.23 2.0}}
  do_test func-4.7 {
    catchsql {SELECT round(b,0) FROM t1 ORDER BY a}
  } {0 {2.0 1.0 -2.0}}
  do_test func-4.8 {
    catchsql {SELECT round(c) FROM t1 ORDER BY a}
  } {0 {3.0 -12346.0 -5.0}}
  do_test func-4.9 {
    catchsql {SELECT round(c,a) FROM t1 ORDER BY a}
  } {0 {3.0 -12345.68 -5.0}}
  do_test func-4.10 {
    catchsql {SELECT 'x' || round(c,a) || 'y' FROM t1 ORDER BY a}
  } {0 {x3.0y x-12345.68y x-5.0y}}
  do_test func-4.11 {
    catchsql {SELECT round() FROM t1 ORDER BY a}
  } {1 {wrong number of arguments to function round()}}
  do_test func-4.12 {
    execsql {SELECT coalesce(round(a,2),'nil') FROM t2}
  } {1.0 nil 345.0 nil 67890.0}
  do_test func-4.13 {
    execsql {SELECT round(t1,2) FROM tbl1}
  } {0.0 0.0 0.0 0.0 0.0}
  do_test func-4.14 {
    execsql {SELECT typeof(round(5.1,1));}
  } {real}
  do_test func-4.15 {
    execsql {SELECT typeof(round(5.1));}
  } {real}
  do_test func-4.16 {
    catchsql {SELECT round(b,2.0) FROM t1 ORDER BY b}
  } {0 {-2.0 1.23 2.0}}
  # Verify some values reported on the mailing list.
  # Some of these fail on MSVC builds with 64-bit
  # long doubles, but not on GCC builds with 80-bit
  # long doubles.
  for {set i 1} {$i<999} {incr i} {
    set x1 [expr 40222.5 + $i]
    set x2 [expr 40223.0 + $i]
    do_test func-4.17.$i {
      execsql {SELECT round($x1);}
    } $x2
  }
  for {set i 1} {$i<999} {incr i} {
    set x1 [expr 40222.05 + $i]
    set x2 [expr 40222.10 + $i]
    do_test func-4.18.$i {
      execsql {SELECT round($x1,1);}
    } $x2
  }
  do_test func-4.20 {
    execsql {SELECT round(40223.4999999999);}
  } {40223.0}
  do_test func-4.21 {
    execsql {SELECT round(40224.4999999999);}
  } {40224.0}
  do_test func-4.22 {
    execsql {SELECT round(40225.4999999999);}
  } {40225.0}
  for {set i 1} {$i<10} {incr i} {
    do_test func-4.23.$i {
      execsql {SELECT round(40223.4999999999,$i);}
    } {40223.5}
    do_test func-4.24.$i {
      execsql {SELECT round(40224.4999999999,$i);}
    } {40224.5}
    do_test func-4.25.$i {
      execsql {SELECT round(40225.4999999999,$i);}
    } {40225.5}
  }
  for {set i 10} {$i<32} {incr i} {
    do_test func-4.26.$i {
      execsql {SELECT round(40223.4999999999,$i);}
    } {40223.4999999999}
    do_test func-4.27.$i {
      execsql {SELECT round(40224.4999999999,$i);}
    } {40224.4999999999}
    do_test func-4.28.$i {
      execsql {SELECT round(40225.4999999999,$i);}
    } {40225.4999999999}
  }
  do_test func-4.29 {
    execsql {SELECT round(1234567890.5);}
  } {1234567891.0}
  do_test func-4.30 {
    execsql {SELECT round(12345678901.5);}
  } {12345678902.0}
  do_test func-4.31 {
    execsql {SELECT round(123456789012.5);}
  } {123456789013.0}
  do_test func-4.32 {
    execsql {SELECT round(1234567890123.5);}
  } {1234567890124.0}
  do_test func-4.33 {
    execsql {SELECT round(12345678901234.5);}
  } {12345678901235.0}
  do_test func-4.34 {
    execsql {SELECT round(1234567890123.35,1);}
  } {1234567890123.4}
  do_test func-4.35 {
    execsql {SELECT round(1234567890123.445,2);}
  } {1234567890123.45}
  do_test func-4.36 {
    execsql {SELECT round(99999999999994.5);}
  } {99999999999995.0}
  do_test func-4.37 {
    execsql {SELECT round(9999999999999.55,1);}
  } {9999999999999.6}
  do_test func-4.38 {
    execsql {SELECT round(9999999999999.556,2);}
  } {9999999999999.56}
}

# Test the upper() and lower() functions
#
do_test func-5.1 {
  execsql {SELECT upper(t1) FROM tbl1}
} {THIS PROGRAM IS FREE SOFTWARE}
do_test func-5.2 {
  execsql {SELECT lower(upper(t1)) FROM tbl1}
} {this program is free software}
do_test func-5.3 {
  execsql {SELECT upper(a), lower(a) FROM t2}
} {1 1 {} {} 345 345 {} {} 67890 67890}
ifcapable !icu {
  do_test func-5.4 {
    catchsql {SELECT upper(a,5) FROM t2}
  } {1 {wrong number of arguments to function upper()}}
}
do_test func-5.5 {
  catchsql {SELECT upper(*) FROM t2}
} {1 {wrong number of arguments to function upper()}}

# Test the coalesce() and nullif() functions
#
do_test func-6.1 {
  execsql {SELECT coalesce(a,'xyz') FROM t2}
} {1 xyz 345 xyz 67890}
do_test func-6.2 {
  execsql {SELECT coalesce(upper(a),'nil') FROM t2}
} {1 nil 345 nil 67890}
do_test func-6.3 {
  execsql {SELECT coalesce(nullif(1,1),'nil')}
} {nil}
do_test func-6.4 {
  execsql {SELECT coalesce(nullif(1,2),'nil')}
} {1}
do_test func-6.5 {
  execsql {SELECT coalesce(nullif(1,NULL),'nil')}
} {1}


# # Test the last_insert_rowid() function
# #
# do_test func-7.1 {
#   execsql {SELECT last_insert_rowid()}
# } [db last_insert_rowid]

# Tests for aggregate functions and how they handle NULLs.
#
ifcapable floatingpoint {
  do_test func-8.1 {
    ifcapable explain {
      execsql {EXPLAIN SELECT sum(a) FROM t2;}
    }
    execsql {
      SELECT sum(a), count(a), round(avg(a),2), min(a), max(a), count(*) FROM t2;
    }
  } {68236 3 22745.33 1 67890 5}
}
ifcapable !floatingpoint {
  do_test func-8.1 {
    ifcapable explain {
      execsql {EXPLAIN SELECT sum(a) FROM t2;}
    }
    execsql {
      SELECT sum(a), count(a), avg(a), min(a), max(a), count(*) FROM t2;
    }
  } {68236 3 22745.0 1 67890 5}
}
do_test func-8.2 {
  execsql {
    SELECT max('z+'||a||'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP') FROM t2;
  }
} {z+67890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP}

# ifcapable tempdb {
#   do_test func-8.3 {
#     execsql {
#       CREATE TEMP TABLE t3 AS SELECT a FROM t2 ORDER BY a DESC;
#       SELECT min('z+'||a||'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP') FROM t3;
#     }
#   } {z+1abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP}
# } else {
#   do_test func-8.3 {
#     execsql {
#       CREATE TABLE t3 AS SELECT a FROM t2 ORDER BY a DESC;
#       SELECT min('z+'||a||'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP') FROM t3;
#     }
#   } {z+1abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP}
# }
# do_test func-8.4 {
#   execsql {
#     SELECT max('z+'||a||'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP') FROM t3;
#   }
# } {z+67890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP}
ifcapable compound {
  do_test func-8.5 {
    execsql {
      SELECT sum(x) FROM (SELECT '9223372036' || '854775807' AS x
                          UNION ALL SELECT -9223372036854775807)
    }
  } {0}
  do_test func-8.6 {
    execsql {
      SELECT typeof(sum(x)) FROM (SELECT '9223372036' || '854775807' AS x
                          UNION ALL SELECT -9223372036854775807)
    }
  } {integer}
  do_test func-8.7 {
    execsql {
      SELECT typeof(sum(x)) FROM (SELECT '9223372036' || '854775808' AS x
                          UNION ALL SELECT -9223372036854775807)
    }
  } {real}
ifcapable floatingpoint {
  do_test func-8.8 {
    execsql {
      SELECT sum(x)>0.0 FROM (SELECT '9223372036' || '854775808' AS x
                          UNION ALL SELECT -9223372036850000000)
    }
  } {1}
}
ifcapable !floatingpoint {
  do_test func-8.8 {
    execsql {
      SELECT sum(x)>0 FROM (SELECT '9223372036' || '854775808' AS x
                          UNION ALL SELECT -9223372036850000000)
    }
  } {1}
}
}

# How do you test the random() function in a meaningful, deterministic way?
#
do_test func-9.1 {
  execsql {
    SELECT random() is not null;
  }
} {1}
do_test func-9.2 {
  execsql {
    SELECT typeof(random());
  }
} {integer}
do_test func-9.3 {
  execsql {
    SELECT randomblob(32) is not null;
  }
} {1}
do_test func-9.4 {
  execsql {
    SELECT typeof(randomblob(32));
  }
} {blob}
do_test func-9.5 {
  execsql {
    SELECT length(randomblob(32)), length(randomblob(-5)),
           length(randomblob(2000))
  }
} {32 1 2000}

# The "hex()" function was added in order to be able to render blobs
# generated by randomblob().  So this seems like a good place to test
# hex().
#
ifcapable bloblit {
  do_test func-9.10 {
    execsql {SELECT hex(x'00112233445566778899aAbBcCdDeEfF')}
  } {00112233445566778899AABBCCDDEEFF}
}
set encoding [db one {PRAGMA encoding}]
if {$encoding=="UTF-16le"} {
  do_test func-9.11-utf16le {
    execsql {SELECT hex(replace('abcdefg','ef','12'))}
  } {6100620063006400310032006700}
  do_test func-9.12-utf16le {
    execsql {SELECT hex(replace('abcdefg','','12'))}
  } {6100620063006400650066006700}
  do_test func-9.13-utf16le {
    execsql {SELECT hex(replace('aabcdefg','a','aaa'))}
  } {610061006100610061006100620063006400650066006700}
} elseif {$encoding=="UTF-8"} {
  do_test func-9.11-utf8 {
    execsql {SELECT hex(replace('abcdefg','ef','12'))}
  } {61626364313267}
  do_test func-9.12-utf8 {
    execsql {SELECT hex(replace('abcdefg','','12'))}
  } {61626364656667}
  do_test func-9.13-utf8 {
    execsql {SELECT hex(replace('aabcdefg','a','aaa'))}
  } {616161616161626364656667}
}
  
# Use the "sqlite_register_test_function" TCL command which is part of
# the text fixture in order to verify correct operation of some of
# the user-defined SQL function APIs that are not used by the built-in
# functions.
#
set ::DB [sqlite3_connection_pointer db]
sqlite_register_test_function $::DB testfunc
do_test func-10.1 {
  catchsql {
    SELECT testfunc(NULL,NULL);
  }
} {1 {first argument should be one of: int int64 string double null value}}
do_test func-10.2 {
  execsql {
    SELECT testfunc(
     'string', 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
     'int', 1234
    );
  }
} {1234}
do_test func-10.3 {
  execsql {
    SELECT testfunc(
     'string', 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
     'string', NULL
    );
  }
} {{}}

ifcapable floatingpoint {
  do_test func-10.4 {
    execsql {
      SELECT testfunc(
       'string', 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
       'double', 1.234
      );
    }
  } {1.234}
  do_test func-10.5 {
    execsql {
      SELECT testfunc(
       'string', 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
       'int', 1234,
       'string', 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
       'string', NULL,
       'string', 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
       'double', 1.234,
       'string', 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
       'int', 1234,
       'string', 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
       'string', NULL,
       'string', 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
       'double', 1.234
      );
    }
  } {1.234}
}

# # Test the built-in sqlite_version(*) SQL function.
# #
# do_test func-11.1 {
#   execsql {
#     SELECT sqlite_version(*);
#   }
# } [sqlite3 -version]

# Test that destructors passed to sqlite3 by calls to sqlite3_result_text()
# etc. are called. These tests use two special user-defined functions
# (implemented in func.c) only available in test builds. 
#
# Function test_destructor() takes one argument and returns a copy of the
# text form of that argument. A destructor is associated with the return
# value. Function test_destructor_count() returns the number of outstanding
# destructor calls for values returned by test_destructor().
#
if {[db eval {PRAGMA encoding}]=="UTF-8"} {
  do_test func-12.1-utf8 {
    execsql {
      SELECT test_destructor('hello world'), test_destructor_count();
    }
  } {{hello world} 1}
} else {
    ifcapable {utf16} {
      do_test func-12.1-utf16 {
        execsql {
          SELECT test_destructor16('hello world'), test_destructor_count();
        }
      } {{hello world} 1}
    }
}
do_test func-12.2 {
  execsql {
    SELECT test_destructor_count();
  }
} {0}
do_test func-12.3 {
  execsql {
    SELECT test_destructor('hello')||' world'
  }
} {{hello world}}
do_test func-12.4 {
  execsql {
    SELECT test_destructor_count();
  }
} {0}
do_test func-12.5 {
  execsql {
    CREATE TABLE t4(id integer primary key, x);
    INSERT INTO t4 VALUES(1, test_destructor('hello'));
    INSERT INTO t4 VALUES(2, test_destructor('world'));
    SELECT min(test_destructor(x)), max(test_destructor(x)) FROM t4;
  }
} {hello world}
do_test func-12.6 {
  execsql {
    SELECT test_destructor_count();
  }
} {0}
do_test func-12.7 {
  execsql {
    DROP TABLE t4;
  }
} {}


# Test that the auxdata API for scalar functions works. This test uses
# a special user-defined function only available in test builds,
# test_auxdata(). Function test_auxdata() takes any number of arguments.
do_test func-13.1 {
  execsql {
    SELECT test_auxdata('hello world');
  }
} {0}

do_test func-13.2 {
  execsql {
    CREATE TABLE t4(id integer primary key, a, b);
    INSERT INTO t4 VALUES(1, 'abc', 'def');
    INSERT INTO t4 VALUES(2, 'ghi', 'jkl');
  }
} {}
do_test func-13.3 {
  execsql {
    SELECT test_auxdata('hello world') FROM t4;
  }
} {0 1}
do_test func-13.4 {
  execsql {
    SELECT test_auxdata('hello world', 123) FROM t4;
  }
} {{0 0} {1 1}}
do_test func-13.5 {
  execsql {
    SELECT test_auxdata('hello world', a) FROM t4;
  }
} {{0 0} {1 0}}
do_test func-13.6 {
  execsql {
    SELECT test_auxdata('hello'||'world', a) FROM t4;
  }
} {{0 0} {1 0}}

# Test that auxilary data is preserved between calls for SQL variables.
do_test func-13.7 {
  set DB [sqlite3_connection_pointer db]
  set sql "SELECT test_auxdata( ? , a ) FROM t4;"
  set STMT [sqlite3_prepare $DB $sql -1 TAIL]
  sqlite3_bind_text $STMT 1 hello\000 -1
  set res [list]
  while { "SQLITE_ROW"==[sqlite3_step $STMT] } {
    lappend res [sqlite3_column_text $STMT 0]
  }
  lappend res [sqlite3_finalize $STMT]
} {{0 0} {1 0} SQLITE_OK}

# Test that auxiliary data is discarded when a statement is reset.
do_execsql_test 13.8.1 {
  SELECT test_auxdata('constant') FROM t4;
} {0 1}
do_execsql_test 13.8.2 {
  SELECT test_auxdata('constant') FROM t4;
} {0 1}
db cache flush
do_execsql_test 13.8.3 {
  SELECT test_auxdata('constant') FROM t4;
} {0 1}
set V "one"
do_execsql_test 13.8.4 {
  SELECT test_auxdata($V), $V FROM t4;
} {0 one 1 one}
set V "two"
do_execsql_test 13.8.5 {
  SELECT test_auxdata($V), $V FROM t4;
} {0 two 1 two}
db cache flush
set V "three"
do_execsql_test 13.8.6 {
  SELECT test_auxdata($V), $V FROM t4;
} {0 three 1 three}


# Make sure that a function with a very long name is rejected
do_test func-14.1 {
  catch {
    db function [string repeat X 254] {return "hello"}
  } 
} {0}
do_test func-14.2 {
  catch {
    db function [string repeat X 256] {return "hello"}
  }
} {1}

do_test func-15.1 {
  catchsql {select test_error(NULL)}
} {1 {}}
do_test func-15.2 {
  catchsql {select test_error('this is the error message')}
} {1 {this is the error message}}
do_test func-15.3 {
  catchsql {select test_error('this is the error message',12)}
} {1 {this is the error message}}
do_test func-15.4 {
  db errorcode
} {12}

# MUST_WORK_TEST

# Test the quote function for BLOB and NULL values.
do_test func-16.1 {
  execsql {
    CREATE TABLE tbl2(id integer primary key, a, b);
  }
  set STMT [sqlite3_prepare $::DB "INSERT INTO tbl2 VALUES(1, ?, ?)" -1 TAIL]
  sqlite3_bind_blob $::STMT 1 abc 3
  sqlite3_step $::STMT
  sqlite3_finalize $::STMT
  execsql {
    SELECT quote(a), quote(b) FROM tbl2;
  }
} {X'616263' NULL}

# Correctly handle function error messages that include %.  Ticket #1354
#
do_test func-17.1 {
  proc testfunc1 args {error "Error %d with %s percents %p"}
  db function testfunc1 ::testfunc1
  catchsql {
    SELECT testfunc1(1,2,3);
  }
} {1 {Error %d with %s percents %p}}

# The SUM function should return integer results when all inputs are integer.
#
do_test func-18.1 {
  execsql {
    CREATE TABLE t5(id int primary key, x);
    INSERT INTO t5 VALUES(1, 1);
    INSERT INTO t5 VALUES(2, -99);
    INSERT INTO t5 VALUES(3, 10000);
    SELECT sum(x) FROM t5;
  }
} {9902}
ifcapable floatingpoint {
  do_test func-18.2 {
    execsql {
      INSERT INTO t5 VALUES(4, 0.0);
      SELECT sum(x) FROM t5;
    }
  } {9902.0}
}

# The sum of nothing is NULL.  But the sum of all NULLs is NULL.
#
# The TOTAL of nothing is 0.0.
#
do_test func-18.3 {
  execsql {
    DELETE FROM t5;
    SELECT sum(x), total(x) FROM t5;
  }
} {{} 0.0}
do_test func-18.4 {
  execsql {
    INSERT INTO t5 VALUES(1, NULL);
    SELECT sum(x), total(x) FROM t5
  }
} {{} 0.0}
do_test func-18.5 {
  execsql {
    INSERT INTO t5 VALUES(2, NULL);
    SELECT sum(x), total(x) FROM t5
  }
} {{} 0.0}
do_test func-18.6 {
  execsql {
    INSERT INTO t5 VALUES(3, 123);
    SELECT sum(x), total(x) FROM t5
  }
} {123 123.0}

# Ticket #1664, #1669, #1670, #1674: An integer overflow on SUM causes
# an error. The non-standard TOTAL() function continues to give a helpful
# result.
#
do_test func-18.10 {
  execsql {
    CREATE TABLE t6(id primary key, x INTEGER);
    INSERT INTO t6 VALUES(1, 1);
    INSERT INTO t6 VALUES(2, 1<<62);
    SELECT sum(x) - ((1<<62)+1) from t6;
  }
} 0
do_test func-18.11 {
  execsql {
    SELECT typeof(sum(x)) FROM t6
  }
} integer
ifcapable floatingpoint {
  do_test func-18.12 {
    catchsql {
      INSERT INTO t6 VALUES(3, 1<<62);
      SELECT sum(x) - ((1<<62)*2.0+1) from t6;
    }
  } {1 {integer overflow}}
  do_test func-18.13 {
    execsql {
      SELECT total(x) - ((1<<62)*2.0+1) FROM t6
    }
  } 0.0
}
ifcapable !floatingpoint {
  do_test func-18.12 {
    catchsql {
      INSERT INTO t6 VALUES(4, 1<<62);
      SELECT sum(x) - ((1<<62)*2+1) from t6;
    }
  } {1 {integer overflow}}
  do_test func-18.13 {
    execsql {
      SELECT total(x) - ((1<<62)*2+1) FROM t6
    }
  } 0.0
}
if {[working_64bit_int]} {
  do_test func-18.14 {
    execsql {
      SELECT sum(-9223372036854775805);
    }
  } -9223372036854775805
}
ifcapable compound&&subquery {

do_test func-18.15 {
  catchsql {
    SELECT sum(x) FROM 
       (SELECT 9223372036854775807 AS x UNION ALL
        SELECT 10 AS x);
  }
} {1 {integer overflow}}
if {[working_64bit_int]} {
  do_test func-18.16 {
    catchsql {
      SELECT sum(x) FROM 
         (SELECT 9223372036854775807 AS x UNION ALL
          SELECT -10 AS x);
    }
  } {0 9223372036854775797}
  do_test func-18.17 {
    catchsql {
      SELECT sum(x) FROM 
         (SELECT -9223372036854775807 AS x UNION ALL
          SELECT 10 AS x);
    }
  } {0 -9223372036854775797}
}
do_test func-18.18 {
  catchsql {
    SELECT sum(x) FROM 
       (SELECT -9223372036854775807 AS x UNION ALL
        SELECT -10 AS x);
  }
} {1 {integer overflow}}
do_test func-18.19 {
  catchsql {
    SELECT sum(x) FROM (SELECT 9 AS x UNION ALL SELECT -10 AS x);
  }
} {0 -1}
do_test func-18.20 {
  catchsql {
    SELECT sum(x) FROM (SELECT -9 AS x UNION ALL SELECT 10 AS x);
  }
} {0 1}
do_test func-18.21 {
  catchsql {
    SELECT sum(x) FROM (SELECT -10 AS x UNION ALL SELECT 9 AS x);
  }
} {0 -1}
do_test func-18.22 {
  catchsql {
    SELECT sum(x) FROM (SELECT 10 AS x UNION ALL SELECT -9 AS x);
  }
} {0 1}

} ;# ifcapable compound&&subquery

# Integer overflow on abs()
#
if {[working_64bit_int]} {
  do_test func-18.31 {
    catchsql {
      SELECT abs(-9223372036854775807);
    }
  } {0 9223372036854775807}
}
do_test func-18.32 {
  catchsql {
    SELECT abs(-9223372036854775807-1);
  }
} {1 {integer overflow}}

# The MATCH function exists but is only a stub and always throws an error.
#
do_test func-19.1 {
  execsql {
    SELECT match(a,b) FROM t1 WHERE 0;
  }
} {}
do_test func-19.2 {
  catchsql {
    SELECT 'abc' MATCH 'xyz';
  }
} {1 {unable to use function MATCH in the requested context}}
do_test func-19.3 {
  catchsql {
    SELECT 'abc' NOT MATCH 'xyz';
  }
} {1 {unable to use function MATCH in the requested context}}
do_test func-19.4 {
  catchsql {
    SELECT match(1,2,3);
  }
} {1 {wrong number of arguments to function match()}}

# Soundex tests.
#
if {![catch {db eval {SELECT soundex('hello')}}]} {
  set i 0
  foreach {name sdx} {
    euler        E460
    EULER        E460
    Euler        E460
    ellery       E460
    gauss        G200
    ghosh        G200
    hilbert      H416
    Heilbronn    H416
    knuth        K530
    kant         K530
    Lloyd        L300
    LADD         L300
    Lukasiewicz  L222
    Lissajous    L222
    A            A000
    12345        ?000
  } {
    incr i
    do_test func-20.$i {
      execsql {SELECT soundex($name)}
    } $sdx
  }
}

# Tests of the REPLACE function.
#
do_test func-21.1 {
  catchsql {
    SELECT replace(1,2);
  }
} {1 {wrong number of arguments to function replace()}}
do_test func-21.2 {
  catchsql {
    SELECT replace(1,2,3,4);
  }
} {1 {wrong number of arguments to function replace()}}
do_test func-21.3 {
  execsql {
    SELECT typeof(replace("This is the main test string", NULL, "ALT"));
  }
} {null}
do_test func-21.4 {
  execsql {
    SELECT typeof(replace(NULL, "main", "ALT"));
  }
} {null}
do_test func-21.5 {
  execsql {
    SELECT typeof(replace("This is the main test string", "main", NULL));
  }
} {null}
do_test func-21.6 {
  execsql {
    SELECT replace("This is the main test string", "main", "ALT");
  }
} {{This is the ALT test string}}
do_test func-21.7 {
  execsql {
    SELECT replace("This is the main test string", "main", "larger-main");
  }
} {{This is the larger-main test string}}
do_test func-21.8 {
  execsql {
    SELECT replace("aaaaaaa", "a", "0123456789");
  }
} {0123456789012345678901234567890123456789012345678901234567890123456789}

ifcapable tclvar {
  do_test func-21.9 {
    # Attempt to exploit a buffer-overflow that at one time existed 
    # in the REPLACE function. 
    set ::str "[string repeat A 29998]CC[string repeat A 35537]"
    set ::rep [string repeat B 65536]
    execsql {
      SELECT LENGTH(REPLACE($::str, 'C', $::rep));
    }
  } [expr 29998 + 2*65536 + 35537]
}

# Tests for the TRIM, LTRIM and RTRIM functions.
#
do_test func-22.1 {
  catchsql {SELECT trim(1,2,3)}
} {1 {wrong number of arguments to function trim()}}
do_test func-22.2 {
  catchsql {SELECT ltrim(1,2,3)}
} {1 {wrong number of arguments to function ltrim()}}
do_test func-22.3 {
  catchsql {SELECT rtrim(1,2,3)}
} {1 {wrong number of arguments to function rtrim()}}
do_test func-22.4 {
  execsql {SELECT trim('  hi  ');}
} {hi}
do_test func-22.5 {
  execsql {SELECT ltrim('  hi  ');}
} {{hi  }}
do_test func-22.6 {
  execsql {SELECT rtrim('  hi  ');}
} {{  hi}}
do_test func-22.7 {
  execsql {SELECT trim('  hi  ','xyz');}
} {{  hi  }}
do_test func-22.8 {
  execsql {SELECT ltrim('  hi  ','xyz');}
} {{  hi  }}
do_test func-22.9 {
  execsql {SELECT rtrim('  hi  ','xyz');}
} {{  hi  }}
do_test func-22.10 {
  execsql {SELECT trim('xyxzy  hi  zzzy','xyz');}
} {{  hi  }}
do_test func-22.11 {
  execsql {SELECT ltrim('xyxzy  hi  zzzy','xyz');}
} {{  hi  zzzy}}
do_test func-22.12 {
  execsql {SELECT rtrim('xyxzy  hi  zzzy','xyz');}
} {{xyxzy  hi  }}
do_test func-22.13 {
  execsql {SELECT trim('  hi  ','');}
} {{  hi  }}
if {[db one {PRAGMA encoding}]=="UTF-8"} {
  do_test func-22.14 {
    execsql {SELECT hex(trim(x'c280e1bfbff48fbfbf6869',x'6162e1bfbfc280'))}
  } {F48FBFBF6869}
  do_test func-22.15 {
    execsql {SELECT hex(trim(x'6869c280e1bfbff48fbfbf61',
                             x'6162e1bfbfc280f48fbfbf'))}
  } {6869}
  do_test func-22.16 {
    execsql {SELECT hex(trim(x'ceb1ceb2ceb3',x'ceb1'));}
  } {CEB2CEB3}
}
do_test func-22.20 {
  execsql {SELECT typeof(trim(NULL));}
} {null}
do_test func-22.21 {
  execsql {SELECT typeof(trim(NULL,'xyz'));}
} {null}
do_test func-22.22 {
  execsql {SELECT typeof(trim('hello',NULL));}
} {null}

# This is to test the deprecated sqlite3_aggregate_count() API.
#
ifcapable deprecated {
  do_test func-23.1 {
    sqlite3_create_aggregate db
    execsql {
      SELECT legacy_count() FROM t6;
    }
  } {3}
}

# The group_concat() function.
#
do_test func-24.1 {
  execsql {
    SELECT group_concat(t1) FROM tbl1
  }
} {this,program,is,free,software}
do_test func-24.2 {
  execsql {
    SELECT group_concat(t1,' ') FROM tbl1
  }
} {{this program is free software}}
# do_test func-24.3 {
#   execsql {
#     SELECT group_concat(t1,' ' || rowid || ' ') FROM tbl1
#   }
# } {{this 2 program 3 is 4 free 5 software}}
do_test func-24.4 {
  execsql {
    SELECT group_concat(NULL,t1) FROM tbl1
  }
} {{}}
do_test func-24.5 {
  execsql {
    SELECT group_concat(t1,NULL) FROM tbl1
  }
} {thisprogramisfreesoftware}
do_test func-24.6 {
  execsql {
    SELECT 'BEGIN-'||group_concat(t1) FROM tbl1
  }
} {BEGIN-this,program,is,free,software}

# Ticket #3179:  Make sure aggregate functions can take many arguments.
# None of the built-in aggregates do this, so use the md5sum() from the
# test extensions.
#

unset -nocomplain midargs
set midargs {}
unset -nocomplain midres
set midres {}
unset -nocomplain result
for {set i 1} {$i<[sqlite3_limit db SQLITE_LIMIT_FUNCTION_ARG -1]} {incr i} {
  append midargs ,'/$i'
  append midres /$i
  set result [md5 \
     "this${midres}program${midres}is${midres}free${midres}software${midres}"]
  set sql "SELECT md5sum(t1$midargs) FROM tbl1"
  do_test func-24.7.$i {
     db eval $::sql
  } $result
}

# Ticket #3806.  If the initial string in a group_concat is an empty
# string, the separator that follows should still be present.
#
do_test func-24.8 {
  execsql {
    SELECT group_concat(CASE t1 WHEN 'this' THEN '' ELSE t1 END) FROM tbl1
  }
} {,program,is,free,software}
do_test func-24.9 {
  execsql {
    SELECT group_concat(CASE WHEN t1!='software' THEN '' ELSE t1 END) FROM tbl1
  }
} {,,,,software}

# Ticket #3923.  Initial empty strings have a separator.  But initial
# NULLs do not.
#
do_test func-24.10 {
  execsql {
    SELECT group_concat(CASE t1 WHEN 'this' THEN null ELSE t1 END) FROM tbl1
  }
} {program,is,free,software}
do_test func-24.11 {
  execsql {
   SELECT group_concat(CASE WHEN t1!='software' THEN null ELSE t1 END) FROM tbl1
  }
} {software}
do_test func-24.12 {
  execsql {
    SELECT group_concat(CASE t1 WHEN 'this' THEN ''
                          WHEN 'program' THEN null ELSE t1 END) FROM tbl1
  }
} {,is,free,software}
# Tests to verify ticket http://www.sqlite.org/src/tktview/55746f9e65f8587c0
do_test func-24.13 {
  execsql {
    SELECT typeof(group_concat(x)) FROM (SELECT '' AS x);
  }
} {text}
do_test func-24.14 {
  execsql {
    SELECT typeof(group_concat(x,''))
      FROM (SELECT '' AS x UNION ALL SELECT '');
  }
} {text}


# Use the test_isolation function to make sure that type conversions
# on function arguments do not effect subsequent arguments.
#
do_test func-25.1 {
  execsql {SELECT test_isolation(t1,t1) FROM tbl1}
} {this program is free software}

# Try to misuse the sqlite3_create_function() interface.  Verify that
# errors are returned.
#
do_test func-26.1 {
  abuse_create_function db
} {}

# The previous test (func-26.1) registered a function with a very long
# function name that takes many arguments and always returns NULL.  Verify
# that this function works correctly.
#
do_test func-26.2 {
  set a {}
  for {set i 1} {$i<=$::SQLITE_MAX_FUNCTION_ARG} {incr i} {
    lappend a $i
  }
  db eval "
     SELECT nullx_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789([join $a ,]);
  "
} {{}}
do_test func-26.3 {
  set a {}
  for {set i 1} {$i<=$::SQLITE_MAX_FUNCTION_ARG+1} {incr i} {
    lappend a $i
  }
  catchsql "
     SELECT nullx_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789([join $a ,]);
  "
} {1 {too many arguments on function nullx_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789}}
do_test func-26.4 {
  set a {}
  for {set i 1} {$i<=$::SQLITE_MAX_FUNCTION_ARG-1} {incr i} {
    lappend a $i
  }
  catchsql "
     SELECT nullx_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789([join $a ,]);
  "
} {1 {wrong number of arguments to function nullx_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789()}}
do_test func-26.5 {
  catchsql "
     SELECT nullx_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_12345678a(0);
  "
} {1 {no such function: nullx_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_12345678a}}
do_test func-26.6 {
  catchsql "
     SELECT nullx_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789a(0);
  "
} {1 {no such function: nullx_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789a}}

do_test func-27.1 {
  catchsql {SELECT coalesce()}
} {1 {wrong number of arguments to function coalesce()}}
do_test func-27.2 {
  catchsql {SELECT coalesce(1)}
} {1 {wrong number of arguments to function coalesce()}}
do_test func-27.3 {
  catchsql {SELECT coalesce(1,2)}
} {0 1}

# Ticket 2d401a94287b5
# Unknown function in a DEFAULT expression causes a segfault.
#

# MUST_WORK_TEST

do_test func-28.1 {
  db eval {
    CREATE TABLE t28(id primary key, x, y DEFAULT(nosuchfunc(1)));
  }
  catchsql {
    INSERT INTO t28(x) VALUES(1, 1);
  }
} {1 {unknown function: nosuchfunc()}}

# Verify that the length() and typeof() functions do not actually load
# the content of their argument.
#

# MUST_WORK_TEST

do_test func-29.1 {
  db eval {
    CREATE TABLE t29(id INTEGER PRIMARY KEY, x, y);
    INSERT INTO t29 VALUES(1, 2, 3), (2, NULL, 4), (3, 4.5, 5);
    INSERT INTO t29 VALUES(4, randomblob(1000000), 6);
    INSERT INTO t29 VALUES(5, "hello", 7);
  }
  db close
  sqlite3 db test.db
  sqlite3_db_status db CACHE_MISS 1
  db eval {SELECT typeof(x), length(x), typeof(y) FROM t29 ORDER BY id}
} {integer 1 integer null {} integer real 3 integer blob 1000000 integer text 5 integer}
do_test func-29.2 {
  set x [lindex [sqlite3_db_status db CACHE_MISS 1] 1]
  if {$x<5} {set x 1}
  set x
} {1}
do_test func-29.3 {
  db close
  sqlite3 db test.db
  sqlite3_db_status db CACHE_MISS 1
  db eval {SELECT typeof(+x) FROM t29 ORDER BY id}
} {integer null real blob text}
if {[permutation] != "mmap"} {
  ifcapable !direct_read {
    do_test func-29.4 {
      set x [lindex [sqlite3_db_status db CACHE_MISS 1] 1]
      if {$x>100} {set x many}
      set x
    } {many}
  }
}
do_test func-29.5 {
  db close
  sqlite3 db test.db
  sqlite3_db_status db CACHE_MISS 1
  db eval {SELECT sum(length(x)) FROM t29}
} {1000009}
do_test func-29.6 {
  set x [lindex [sqlite3_db_status db CACHE_MISS 1] 1]
  if {$x<5} {set x 1}
  set x
} {1}

# The OP_Column opcode has an optimization that avoids loading content
# for fields with content-length=0 when the content offset is on an overflow
# page.  Make sure the optimization works.
#
do_execsql_test func-29.10 {
  CREATE TABLE t29b(a primary key,b,c,d,e,f,g,h,i);
  INSERT INTO t29b 
   VALUES(1, hex(randomblob(2000)), null, 0, 1, '', zeroblob(0),'x',x'01');
  SELECT typeof(c), typeof(d), typeof(e), typeof(f),
         typeof(g), typeof(h), typeof(i) FROM t29b;
} {null integer integer text blob text blob}
do_execsql_test func-29.11 {
  SELECT length(f), length(g), length(h), length(i) FROM t29b;
} {0 0 1 1}

# MUST_WORK_TEST

do_execsql_test func-29.12 {
  SELECT quote(f), quote(g), quote(h), quote(i) FROM t29b;
} {'' X'' 'x' X'01'}

# EVIDENCE-OF: R-29701-50711 The unicode(X) function returns the numeric
# unicode code point corresponding to the first character of the string
# X.
#
# EVIDENCE-OF: R-55469-62130 The char(X1,X2,...,XN) function returns a
# string composed of characters having the unicode code point values of
# integers X1 through XN, respectively.
#
do_execsql_test func-30.1 {SELECT unicode('$');} 36
do_execsql_test func-30.2 [subst {SELECT unicode('\u00A2');}] 162
do_execsql_test func-30.3 [subst {SELECT unicode('\u20AC');}] 8364
do_execsql_test func-30.4 {SELECT char(36,162,8364);} [subst {$\u00A2\u20AC}]

for {set i 1} {$i<0xd800} {incr i 13} {
  do_execsql_test func-30.5.$i {SELECT unicode(char($i))} $i
}
for {set i 57344} {$i<=0xfffd} {incr i 17} {
  if {$i==0xfeff} continue
  do_execsql_test func-30.5.$i {SELECT unicode(char($i))} $i
}
for {set i 65536} {$i<=0x10ffff} {incr i 139} {
  do_execsql_test func-30.5.$i {SELECT unicode(char($i))} $i
}

# Test char().
#
do_execsql_test func-31.1 { 
  SELECT char(), length(char()), typeof(char()) 
} {{} 0 text}
finish_test
