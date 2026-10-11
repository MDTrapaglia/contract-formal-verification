# `clusters_ssv.spec`

Esta especificación verifica el modo legacy SSV, donde la contabilidad del
cluster usa el token SSV en vez del balance ETH nativo. Es conceptualmente
parecida a `clusters_eth.spec`, pero usa las funciones `liquidateSSV` y el
estado de snapshots SSV.

## Reglas

### `thirdPartyCannotLiquidateSolventSSV`

Para un cluster SSV activo y solvente, un tercero no propietario debe revertir
al intentar liquidarlo. La regla compara la vista pública con el cálculo
independiente, y verifica que el hash almacenado no cambia tras el revert.
Modela cuatro operadores ordenados, 1–100 validadores, hasta 1.000.000 bloques
de accrual y fees acotados a 1.000.000.000 de unidades.

### `ownerMayAttemptSelfLiquidationSSV`

Busca un estado alcanzable donde el owner pueda auto-liquidar sin revertir. El
testigo usa balance cero para no introducir supuestos sobre transferencias ERC20;
por tanto demuestra autorización y transición de estado, no un pago de tokens.

## Cómo interpretar un PASS

El resultado exitoso significa que no se encontró una violación en el dominio
descrito y que los testigos de alcanzabilidad existen. Debe leerse junto con
los límites del modelo: no es una prueba de todo el contrato ni de todas las
combinaciones de operadores.

## Archivos relacionados

- `../conf/clusters-ssv.conf`: parámetros de ejecución.
- `../harness/SSVClustersCertoraHarness.sol`: estado y cálculos auxiliares.
- `../scripts/run-clusters-ssv.sh`: ejecución reproducible.
- `../RESULTS.md`: enlaces a los resultados cloud.
