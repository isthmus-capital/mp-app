// tests/inventario/letra_v1.mjs
// Reproduce la fórmula §4.6-a del Prompt Maestro y la contrasta con los valores reales de LoanDisk.
// No es el motor de reglas (Brief 06); es evidencia del inventario del Brief 00.
// Regla vinculante (Gianclaudio, 02-oct-2026): la fuente de verdad del total y del calendario es LoanDisk;
// el snapshot se reconcilia con LoanDisk después de crear el préstamo, no se recalcula por fórmula.
const r2 = (x) => Math.round((x + Number.EPSILON) * 100) / 100;

export function cuotaQuincenal({ monto, tasaMensualPct, plazoMeses }) {
  const cuotas = plazoMeses * 2;
  const cuota = r2(monto / cuotas + (monto * tasaMensualPct) / 100 / 2);
  return {
    cuotas,
    cuota,
    totalFormula: r2(cuota * cuotas),                                            // cuota × cuotas (texto §4.6-a)
    totalInteresSimple: r2(monto + (monto * tasaMensualPct * plazoMeses) / 100), // capital + interés flat
  };
}

export function letraFlat({ monto, tasaMensualPct, cuotas }) {
  const meses = cuotas / 2;
  const cuota = r2(monto / cuotas + (monto * tasaMensualPct) / 100 / 2);
  return {
    cuotas,
    cuota,
    totalFormula: r2(cuota * cuotas),
    totalInteresSimple: r2(monto + (monto * tasaMensualPct * meses) / 100),
  };
}

const casos = [
  { id: "SO-00077 / 11909610", esperadoLoanDisk: { cuota: 28.67, total: 172.0 }, calc: cuotaQuincenal({ monto: 100, tasaMensualPct: 24, plazoMeses: 3 }) },
  { id: "16860",               esperadoLoanDisk: { cuota: 84.0,  total: 420.0 }, calc: letraFlat({ monto: 300, tasaMensualPct: 16, cuotas: 5 }) },
  { id: "§4.6 $300 4% 3m",     esperadoLoanDisk: { cuota: 56.0,  total: 336.0 }, calc: cuotaQuincenal({ monto: 300, tasaMensualPct: 4, plazoMeses: 3 }) },
  { id: "§4.6 $300 4% 6m",     esperadoLoanDisk: { cuota: 31.0,  total: 372.0 }, calc: cuotaQuincenal({ monto: 300, tasaMensualPct: 4, plazoMeses: 6 }) },
  { id: "§4.6 $300 4% 9m",     esperadoLoanDisk: { cuota: 22.67, total: 408.0 }, calc: cuotaQuincenal({ monto: 300, tasaMensualPct: 4, plazoMeses: 9 }) },
  { id: "§4.6 $300 4% 12m",    esperadoLoanDisk: { cuota: 18.5,  total: 444.0 }, calc: cuotaQuincenal({ monto: 300, tasaMensualPct: 4, plazoMeses: 12 }) },
];

let fallos = 0;
for (const c of casos) {
  const okCuota = c.calc.cuota === c.esperadoLoanDisk.cuota;
  const okTotalFormula = c.calc.totalFormula === c.esperadoLoanDisk.total;
  const okTotalSimple = c.calc.totalInteresSimple === c.esperadoLoanDisk.total;
  if (!okCuota || !okTotalSimple) fallos++;
  console.log(
    `${c.id.padEnd(24)} cuotas=${String(c.calc.cuotas).padStart(2)} cuota=${c.calc.cuota.toFixed(2)} (${okCuota ? "OK" : "DIF"})` +
    ` total_formula=${c.calc.totalFormula.toFixed(2)} (${okTotalFormula ? "OK" : "DIF " + (c.calc.totalFormula - c.esperadoLoanDisk.total).toFixed(2)})` +
    ` total_interes_simple=${c.calc.totalInteresSimple.toFixed(2)} (${okTotalSimple ? "OK" : "DIF"})`
  );
}
console.log(fallos === 0 ? "\nCuota y capital+interés coinciden con LoanDisk en todos los casos." : `\n${fallos} caso(s) con diferencia en cuota o capital+interés.`);
process.exit(fallos === 0 ? 0 : 1);
