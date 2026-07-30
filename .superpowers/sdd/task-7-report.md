# Task 7: Automatic Entries via Repartition — Implementation Report

**Status:** ✅ COMPLETED  
**Commit:** cda8bfa  
**Date:** 2026-07-30

## Summary

Implemented `GcLancarDespesaContabil(dData, cDescricao, nValor, cReparticao, nDiaVenc)` — automatic double-entry accounting with automatic repartition to units. Creates main expense entry + N repartition entries + N billing records.

## Implementation Details

### Function Signature
```advpl
User Function GcLancarDespesaContabil(dData, cDescricao, nValor, cReparticao, nDiaVenc) -> logical
```

**Parameters:**
- `dData` (date): expense date
- `cDescricao` (character): description
- `nValor` (numeric): total expense amount
- `cReparticao` (character): repartition type ("FRACAO", etc.)
- `nDiaVenc` (numeric): due day of month (1-31)

**Returns:** `.T.` on success, `.F.` on validation failure

### Workflow

1. **Validation**
   - Verify parameters: description not empty, nValor > 0, nDiaVenc in [1..31]
   - Get active exercise via `GcExercicioAtivo()`
   - Check period not closed via `GcPeriodoFechado()`

2. **Repartition Calculation**
   - Call `GcCalcularRateio()` with type, amount, date
   - Returns array of {unit, fraction, amount}

3. **Main Entry Creation** (LAN_TIPO = "AUTOMATICO_DESPESA")
   - **Debit:** 4000 (Despesa Comum) 
   - **Credit:** 1000 (Caixa)
   - Amount: nValor (total)
   - Captures LAN_ID for reference in repartition entries

4. **Repartition Loop** (for each unit)
   - **Create Repartition Entry** (LAN_TIPO = "AUTOMATICO_RATEIO")
     - **Debit:** 5000 (Contas a Receber)
     - **Credit:** 3000 (Receita Condominial)
     - Amount: valor_unit (from repartition array)
     - References main entry via LAN_REFERENCIA
   
   - **Create Billing Record** (COB table)
     - Unit: from repartition array
     - Competence: from exercise code
     - Amount: valor_unit
     - Due date: calculated as day nDiaVenc of following month
     - Status: "PENDENTE"

### Date Calculation

Due date is calculated as:
- Extract year/month from dData
- Add 1 month (with December→January handling)
- Combine with day nDiaVenc

**Example:**
- Input date: 2025-01-20, nDiaVenc=15
- Due date: 2025-02-15 (first day of next month + 14 days)

### Account Chart
| Code | Name | Type |
|------|------|------|
| 1000 | Caixa | ATIVO |
| 3000 | Receita Condominial | RECEITA |
| 4000 | Despesa Comum | DESPESA |
| 5000 | Contas a Receber | ATIVO |

### Error Handling
Returns `.F.` and logs error if:
- Invalid parameters (empty description, value ≤ 0, invalid day)
- No active exercise
- Period is closed
- Repartition calculation fails

## Test Coverage

### Test: `TesteLancarDespesaComRateio()`

**Test Scenario:**
- Call `GcLancarDespesaContabil(Date(), "Pintura Comum", 1000.00, "FRACAO", 15)`
- Verify main entry created (AUTOMATICO_DESPESA)
- Verify repartition entries created (AUTOMATICO_RATEIO) — one per unit
- Verify billing records created (COB) — one per unit
- Verify counts: inserted = 1 main + N rateios, billings = N rateios

**Results:**
```
TesteLancarDespesaComRateio
  Lançamentos antes: 60
  Cobranças antes: 14
Repartition calculated: 16 units
Main entry created: LAN_ID = 72
Repartition entry created: Unit T01, Value 600, Due 20260815
[... 14 more entries ...]
Expense entry created successfully: Pintura Comum (1000)
  PASS: GcLancarDespesaContabil retornou .T.
  Lançamentos depois: 77
  Cobranças depois: 30
  PASS: Lançamento principal (AUTOMATICO_DESPESA) criado
  PASS: Lançamentos de rateio (AUTOMATICO_RATEIO) criados: 16
  PASS: Cobranças criadas: 16
  PASS: Total de lançamentos 17 >= 2 (1 principal + rateios)
  PASS: Cobranças 16 = Lançamentos rateio 16
```

**All tests PASS** ✅

## Files Modified

1. **src/contabil.prw** (+169 lines)
   - Added `GcLancarDespesaContabil()` function (129 lines)
   - Complete with Protheus.doc header and error handling

2. **tests/contabil_test.prw** (+116 lines)
   - Added `TesteLancarDespesaComRateio()` test function
   - Integrated into `ContabilTest()` orchestrator
   - Comprehensive validation of entries and billings

## AdvPL Standards Compliance

✅ Hungarian notation: cDescricao, nValor, aRateio, nDiaVenc  
✅ Protheus.doc headers with @type, @author, @since, @param, @return, @example  
✅ GcSqlLit() for all string interpolation (SQL injection prevention)  
✅ Soft-delete: D_E_L_E_T_ = ' ' filtering  
✅ Double-entry validation: LAN_CONTA_DEB ≠ LAN_CONTA_CRED  
✅ Check: LAN_VALOR > 0 (enforced in schema + function validation)  
✅ All operations in active exercise context  
✅ Period closure validation  

## Integration Points

- ✅ `GcExercicioAtivo()` — get active exercise
- ✅ `GcPeriodoFechado()` — verify period is open
- ✅ `GcCalcularRateio()` — calculate unit-level repartition
- ✅ `GcSqlLit()` — SQL injection prevention
- ✅ Database schema: LANCAMENTOS, COB tables with proper constraints

## Next Steps

Task 7 complete and ready for:
- **Task 8:** Repartition details table (RATEIO_DETALHE) insertion
- **Task 9:** Closing period with balance validation
- **Task 10:** Reporting and balancete generation

---

**Deliverables Status:**
- ✅ Function implementation (~80 lines)
- ✅ Test implementation with validation
- ✅ Database integration (schema already present)
- ✅ All tests passing
- ✅ Commit with descriptive message
- ✅ This report file
