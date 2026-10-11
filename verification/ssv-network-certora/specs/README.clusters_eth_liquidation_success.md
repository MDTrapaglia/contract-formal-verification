# `clusters_eth_liquidation_success.spec`

Esta especificación cubre la ruta complementaria a la protección anterior:
qué debe ocurrir cuando un cluster ETH es realmente insolvente y un tercero lo
liquida con éxito.

## Regla `successfulInsolventETHLiquidationSettlesAccounting`

La regla configura un cluster activo, exige que el harness lo considere
liquidable y ejecuta `liquidate` desde un tercero que no es el owner ni el
contrato. Si la llamada no revierte, comprueba que:

- el hash almacenado cambia al hash canónico de cluster liquidado;
- los contadores ETH del DAO y de cada uno de los cuatro operadores quedan en
  cero;
- las vUnits del DAO y operadores quedan en cero;
- el balance ETH del protocolo disminuye exactamente por `cluster.balance`;
- el liquidator recibe exactamente ese balance.

El `satisfy` exige encontrar una ejecución exitosa con balance positivo. Así se
distingue entre una propiedad correcta y una regla que solo observa llamadas
revertidas.

## Supuestos importantes

Se usan cuatro operadores distintos y ordenados, hasta 100 validadores, bloque
representable por `uint32`, balance suficiente del protocolo y sin `msg.value`.
Los casos con errores de transferencia externa, otros tamaños de operador o
balances extremos requieren reglas adicionales.

## Interpretación

La prueba demuestra la liquidación y su contabilidad posterior en el estado
modelado; no constituye una prueba completa de todos los caminos de
liquidación del protocolo. El resultado y la configuración de ejecución están
en `../RESULTS.md` y `../conf/`.
