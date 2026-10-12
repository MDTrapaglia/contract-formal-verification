# Cómo leer los archivos `.conf`

Los archivos JSON de `conf/` son la receta que recibe `certoraRun`. Cada uno
elige una especificación distinta, pero comparte el mismo contrato harness.

## Campos comunes

| Campo | Función |
|---|---|
| `files` | Fuentes Solidity que Certora compila. Aquí apunta al harness. |
| `verify` | Objetivo y especificación, con formato `Contrato:spec`. |
| `solc` | Compilador Solidity que se resolverá desde el entorno. |
| `solc_optimize` | Nivel de optimización usado al compilar. |
| `solc_via_ir` | Compila mediante la representación intermedia de Solidity. |
| `solc_evm_version` | Reglas de bytecode/EVM; aquí `cancun`. |
| `optimistic_loop` | Permite el tratamiento optimista de ciertos loops. |
| `loop_iter` | Límite de iteraciones usado para ese análisis (`4`). |
| `rule_sanity` | Ejecuta comprobaciones básicas de alcanzabilidad de reglas. |
| `ignore_solidity_warnings` | No convierte warnings Solidity en errores de la corrida. |
| `wait_for_results` | Espera a que terminen los jobs solicitados. |
| `msg` | Etiqueta humana del job en Certora Cloud. |

## Qué cambia entre configuraciones

Solo cambia principalmente `verify` y `msg`:

- `clusters-eth.conf` → `specs/clusters_eth.spec`.
- `clusters-eth-liquidation-success.conf` → liquidación ETH exitosa.
- `clusters-eth-withdraw.conf` → retiros ETH.
- `clusters-ssv.conf` → liquidación legacy SSV.

Esto permite comparar suites con el mismo compilador y harness. Si se cambia un
límite del modelo, una versión de Solidity o una opción del solver, conviene
registrarlo en `RESULTS.md`, porque puede cambiar tiempos y cobertura.

## Check local frente a Cloud

Los scripts aceptan `check` o `verify`:

```bash
bash certora/scripts/run-clusters-eth.sh check
bash certora/scripts/run-clusters-eth.sh verify
```

`check` valida formato, compilación y escenas sin enviar un job. `verify`
requiere `CERTORAKEY` (o `CERTORA`, que el script copia a `CERTORAKEY`) y envía
la prueba a Cloud. Nunca se debe guardar la clave en Git.

## Nota sobre este repositorio

Esta carpeta contiene una copia documentada de los artefactos de Certora. Los
`.conf` conservan las rutas del repositorio fuente original (`certora/...`).
Para ejecutar sin adaptar rutas, usa el checkout fuente de SSV Network; si
ejecutas desde esta copia, ajusta `files`, `verify` y las rutas de los scripts
para que apunten a `harness/` y `specs/` locales.
