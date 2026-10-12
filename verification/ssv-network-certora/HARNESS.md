# Cómo leer `SSVClustersCertoraHarness.sol`

El harness es un contrato Solidity de apoyo. No es una implementación nueva
del protocolo: hereda `SSVClusters` y `SSVViews`, inicializa el almacenamiento
que Certora necesita y expone funciones auxiliares para expresar el modelo.

## Herencia y almacenamiento

```solidity
contract SSVClustersCertoraHarness is SSVClusters, SSVViews
```

Así las llamadas `liquidate`, `liquidateSSV`, `withdraw` y las vistas se
resuelven contra el código real heredado. El harness escribe directamente las
estructuras de almacenamiento del protocolo mediante `SSVStorage*`; esto crea
un estado controlado y reproducible antes de cada regla.

## Familias de helpers

- `certoraSetETHProtocol*` y `certoraSetSSVProtocol` inicializan fees, índices,
  snapshots, umbrales, balances DAO y guard de reentrancia.
- `certoraSetETHCluster*` y `certoraSetSSVCluster` crean el hash del cluster y
  los datos de owner, operadores, snapshots y contadores.
- Las variantes `WithAccrual` colocan snapshots en un bloque anterior para
  modelar fees acumuladas hasta `block.number`.
- `certoraSetClusterVUnits` configura vUnits explícitas y distribuye la
  desviación a los operadores.
- `certoraIsCurrent*Liquidatable`, `certoraETHBurnRate` y helpers equivalentes
  calculan el estado actual sin modificarlo.
- `certoraExpected*Hash` construyen el hash esperado después de liquidación o
  retiro.
- Los getters (`certoraStored...`, contadores y vUnits) permiten que CVL haga
  assertions sobre almacenamiento posterior a una llamada.

## Por qué son importantes los helpers

Una regla CVL no debería depender de una secuencia enorme de transacciones
reales para alcanzar cada estado. El harness configura directamente las
precondiciones relevantes y deja que la operación bajo prueba sea la llamada
real heredada. Las funciones auxiliares no reemplazan esa llamada: sirven para
preparar el estado, calcular una referencia independiente o inspeccionar el
resultado.

## Qué significa una comparación independiente

Las reglas calculan liquidabilidad/hash con helpers separados y los comparan
con la vista o el almacenamiento producido por el contrato. Si ambos cálculos
compartieran exactamente el mismo código, un bug podría copiarse en ambos; por
eso la separación del helper y la ruta real es parte del diseño de la prueba.

## Límites y precauciones

El harness modela solo el estado necesario para estas suites: cuatro
operadores, contadores, índices, vUnits y balances relevantes. No inicializa
automáticamente todo el protocolo ni demuestra propiedades de funciones que no
aparecen en las especificaciones. Los límites de bloques, fees y validadores
están en los `require` de cada `.spec`; cambiar el harness sin actualizar esos
supuestos puede producir pruebas vacías o resultados engañosos.

Para investigar una discrepancia, revisar primero el helper que inicializa el
slot, después la función real heredada y finalmente el `assert` que observa el
resultado. Los datos generados en `.certora_internal/` son diagnósticos locales
y se mantienen fuera del repositorio.
