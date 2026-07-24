// tests/db_test.prw
#include "totvs.ch"
#include "../src/db.prw"
User Function DbTest()
    Local cEscapado := GcSqlLit("O'Brien")
    ConOut("escapado=[" + cEscapado + "]")
Return
