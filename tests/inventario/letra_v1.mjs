// tests/inventario/letra_v1.mjs
// Reproduce la regla §4.6-a del Prompt Maestro (v5.1, decisión 02-oct-2026) contra los valores reales de LoanDisk.
// No es el motor de reglas (Brief 06); es evidencia del inventario del Brief 00.
// Regla: total_pagar = capital + interés flat; cuota = redondear2(total / cuotas); la última cuota absorbe los centavos.
// El calendario que devuelve LoanDisk es la fuente de verdad del snapshot; si difiere, mp_loandisk_crear alerta.
const r2 = (x) => Math.round((x + Number.EPSILON) * 100) / 100;

export function letraFlat({ monto, tasaMensualPct, plazoMeses, cuotas }) {
  cuotas = cuotas ?? plazoMeses * 2;
  const meses = plazoMeses ?? cuotas / 2;
  const interesTotal = r2((monto * tasaMensualPct * meses) / 100);
  const total = r2(monto + interesTotal);
  const cuota = r2(total / cuotas);
  const ultimaCuota = r2(total - cuota * (cuotas - 1));
  return { cuotas, cuota, ultimaCuota, total, interesTotal, totalCuotaPorCuotas: r2(cuota * cuotas) };
}

// esperado: valores reales (fuente LoanDisk/CRM) o de la tabla §4.6 del Prompt Maestro (fuente PM)
const casos = [
  { id: "SO-00078 / 11909610", fuente: "LoanDisk", in: { monto: 100, tasaMensualPct: 24, plazoMeses: 3 }, esperado: { cuota: 28.67, ultimaCuota: 28.65, total: 172.0 } },
  { id: "SO-00079 / 11913796", fuente: "LoanDisk", in: { monto: 300, tasaMensualPct: 24, plazoMeses: 3 }, esperado: { cuota: 86.0,  ultimaCuota: 86.0,  total: 516.0 } },
  { id: "16860",               fuente: "LoanDisk", in: { monto: 300, tasaMensualPct: 16, cuotas: 5 },      esperado: { cuota: 84.0,  ultimaCuota: 84.0,  total: 420.0 } },
  { id: "§4.6 $300 4% 3m",     fuente: "PM",       in: { monto: 300, tasaMensualPct: 4, plazoMeses: 3 },  esperado: { cuota: 56.0,  ultimaCuota: 56.0,  total: 336.0 } },
  { id: "§4.6 $300 4% 6m",     fuente: "PM",       in: { monto: 300, tasaMensualPct: 4, plazoMeses: 6 },  esperado: { cuota: 31.0,  ultimaCuota: 31.0,  total: 372.0 } },
  { id: "§4.6 $300 4% 9m",     fuente: "PM",       in: { monto: 300, tasaMensualPct: 4, plazoMeses: 9 },  esperado: { cuota: 22.67, ultimaCuota: 22.61, total: 408.0 } },
  { id: "§4.6 $300 4% 12m",    fuente: "PM",       in: { monto: 300, tasaMensualPct: 4, plazoMeses: 12 }, esperado: { cuota: 18.5,  ultimaCuota: 18.5,  total: 444.0 } },
];

let fallos = 0;
for (const c of casos) {
  const r = letraFlat(c.in);
  const okCuota = r.cuota === c.esperado.cuota;
  const okUltima = r.ultimaCuota === c.esperado.ultimaCuota;
  const okTotal = r.total === c.esperado.total;
  const okSuma = r2(r.cuota * (r.cuotas - 1) + r.ultimaCuota) === r.total;
  if (!(okCuota && okUltima && okTotal && okSuma)) fallos++;
  const vieja = r.totalCuotaPorCuotas === r.total ? "" : ` [cuota×cuotas=${r.totalCuotaPorCuotas.toFixed(2)}, dif ${(r.totalCuotaPorCuotas - r.total).toFixed(2)}]`;
  console.log(
    `${c.id.padEnd(22)} ${c.fuente.padEnd(8)} cuotas=${String(r.cuotas).padStart(2)} cuota=${r.cuota.toFixed(2)} (${okCuota ? "OK" : "DIF"})` +
    ` ultima=${r.ultimaCuota.toFixed(2)} (${okUltima ? "OK" : "DIF"}) total=${r.total.toFixed(2)} (${okTotal ? "OK" : "DIF"}) suma=${okSuma ? "OK" : "DIF"}${vieja}`
  );
}
console.log(fallos === 0 ? "\nCuota, última cuota y total coinciden con LoanDisk / §4.6 en todos los casos." : `\n${fallos} caso(s) con diferencia.`);
process.exit(fallos === 0 ? 0 : 1);
