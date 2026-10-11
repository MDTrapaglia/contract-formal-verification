# `clusters_eth_withdraw.spec`

Esta especificación estudia retiros del owner desde un cluster ETH. Su objetivo
principal es que un retiro exitoso no deje al cluster en un estado liquidable y
que el hash persistido coincida con el cálculo independiente del harness.

## Reglas

### `successfulWithdrawPreservesETHSolvency`

Para cualquier monto simbólico que logre ejecutarse sin revertir, comprueba que
el monto no supera el balance, que el cluster sigue siendo solvente y que el
hash resultante es el esperado. Incluye vUnits implícitas o explícitas y fees
de red simbólicos.

### `solventETHWithdrawCanSucceed`

Prueba de alcanzabilidad: Certora debe encontrar un retiro no cero exitoso en
un cluster solvente. No prueba una cantidad específica para producción.

### `successfulAccruedETHWithdrawPreservesSolvency`

Repite el invariante después de hasta 1.000.000 bloques de accrual, con fees de
operador y red simbólicos acotados. El harness liquida los índices antes del
retiro y compara tanto solvencia como hash.

### `accruedETHWithdrawCanSucceedWithNonzeroFees`

Exige un testigo con fees de operador y red positivos y al menos un bloque
transcurrido. Confirma que la rama con accrual no es vacía.

## Qué no cubre

Estas reglas no prueban todos los contratos ni todos los tamaños de operador;
usan cuatro IDs distintos y ordenados, clusters activos y hasta 100
validadores. Tampoco sustituyen las pruebas de integración de transferencias.

## Archivos relacionados

Usa `../conf/clusters-eth-withdraw.conf` y los scripts de `../scripts/`. Los
resultados cloud y límites exactos están documentados en `../RESULTS.md`.
