# `clusters_eth.spec`

Esta especificación verifica reglas sobre clusters ETH (la contabilidad nativa
de ETH, no el modo legacy SSV). Certora no ejecuta unos pocos casos de prueba:
explora los estados que cumplen los `require` y demuestra los `assert` para
todos ellos, dentro de los límites indicados.

## Qué se verifica

### `thirdPartyCannotLiquidateSolventETH`

Comprueba que un tercero (`caller != owner`) no puede liquidar un cluster ETH
activo y solvente. La regla compara además `SSVViews.isLiquidatable` con el
cálculo independiente del harness. La llamada debe revertir y el hash guardado
del cluster debe permanecer igual.

El modelo usa cuatro operadores distintos y ordenados, entre 1 y 100
validadores, snapshots con hasta 1.000.000 bloques de antigüedad, y fees de
red/operador acotados a 1.000.000.000 de unidades empaquetadas. Incluye un
`satisfy` que exige un estado alcanzable con fees positivos y tiempo transcurrido;
esto evita que la prueba pase únicamente porque sus precondiciones son
imposibles.

### `ownerMayAttemptSelfLiquidationETH`

Es una prueba de alcanzabilidad de la excepción intencional: Certora debe
encontrar al menos un estado válido donde el owner pueda ejecutar
self-liquidation sin revertir. No afirma que todo owner pueda liquidar siempre.

## Cómo leer el resultado

Un `No errors found by Prover!` significa que no se encontró una violación en
el dominio modelado. No significa que se haya probado cada número posible de
operadores ni todas las funciones del protocolo. Un `satisfy` exitoso confirma
que existe un testigo concreto para esa ruta.

## Archivos relacionados

- `../conf/clusters-eth.conf`: configuración de compilación y ejecución.
- `../harness/SSVClustersCertoraHarness.sol`: inicializa el estado abstracto.
- `../scripts/run-clusters-eth.sh`: entrada reproducible.
- `../RESULTS.md`: jobs cloud y resultados históricos.
