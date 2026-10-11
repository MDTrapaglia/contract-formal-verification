# Handoff: siguientes verificaciones Certora de SSV Network

Este documento permite que otro agente continúe la campaña formal sin depender
del historial del chat. Workspace: `/home/brahman/projects/contract_formal_verif`.
El repositorio Solidity es `repos/ssv-network/`.

## Estado confirmado

Las siguientes verificaciones cloud terminaron con código 0 y
`No errors found by Prover!` (CLI 8.19.2, Solidity 0.8.24, EVM Cancun):

| Propiedad | Resultado | Reporte |
|---|---|---|
| `thirdPartyCannotLiquidateSolventETH` + `ownerMayAttemptSelfLiquidationETH` + comparación ETH view/ejecución | PASS | [ETH](https://prover.certora.com/output/10390566/2e4be3096085456dba076982a58a55df) |
| `thirdPartyCannotLiquidateSolventSSV` + `ownerMayAttemptSelfLiquidationSSV` + comparación SSV view/ejecución | PASS | [SSV](https://prover.certora.com/output/10390566/9df9c62b7d44466487645cfacbec06c3) |
| `successfulWithdrawPreservesETHSolvency` y testigo de retiro exitoso | PASS | [ETH withdraw](https://prover.certora.com/output/10390566/a4f63447e4044b29ae74e150d7871012) |
| `successfulAccruedETHWithdrawPreservesSolvency` y testigo con fees positivos | PASS | [ETH withdraw con accrual](https://prover.certora.com/output/10390566/adda14406f9a4e20860b0db293eb0434) |
| `thirdPartyCannotLiquidateSolventETH` con accrual y fees no cero | PASS | [ETH liquidation con accrual](https://prover.certora.com/output/10390566/7e7ac39862a74b6fb1def7749be41181) |

Los reportes de liquidación incluyen testigos de reachability para la excepción
de self-liquidation del owner y para estados solventes. Las aserciones de view
comparan las funciones reales de `SSVViews` con helpers que calculan por
separado el accrual de índices y el umbral.

## Archivos a consultar

- Plan de campaña y reglas de novedad: `PLAN_VALIDACION_Y_BUSQUEDA_VULNERABILIDADES_SSV.md`.
- Especificaciones: `repos/ssv-network/certora/specs/clusters_eth.spec`,
  `clusters_ssv.spec` y `clusters_eth_withdraw.spec`.
- Harness Solidity y modelos de estado: `repos/ssv-network/certora/harness/SSVClustersCertoraHarness.sol`.
- Parámetros Certora: `repos/ssv-network/certora/conf/`.
- Comandos y resultados conocidos: `repos/ssv-network/certora/README.md` y
  `certora/RESULTS.md`.
- Registro cronológico de esta sesión: `FORMAL_VERIFICATION_PROGRESS.md`.

## Reproducir las corridas

Desde el repositorio del protocolo:

```bash
cd /home/brahman/projects/contract_formal_verif/repos/ssv-network
```

Si la key está en `~/.env`, cárguese sin imprimirla:

```bash
set -a
. ~/.env
set +a
if [ -z "${CERTORAKEY:-}" ] && [ -n "${CERTORA:-}" ]; then
  CERTORAKEY="$CERTORA"
  export CERTORAKEY
fi
```

En este workspace el entorno virtual usado está en el directorio padre del
repo, así que agréguese al `PATH` (si otro entorno ya tiene Certora y solc,
este paso no hace falta):

```bash
export PATH="/home/brahman/projects/contract_formal_verif/.venv-certora/bin:$PATH"
```

Validar formato/compilación local y luego someter cloud, secuencialmente para
evitar colisiones de `.certora_internal/latest`:

```bash
certoraCVLFormatter certora/specs/clusters_eth.spec >/dev/null
certoraRun certora/conf/clusters-eth.conf --compilation_steps_only
certoraRun certora/conf/clusters-eth.conf

certoraCVLFormatter certora/specs/clusters_ssv.spec >/dev/null
certoraRun certora/conf/clusters-ssv.conf --compilation_steps_only
certoraRun certora/conf/clusters-ssv.conf

certoraCVLFormatter certora/specs/clusters_eth_withdraw.spec >/dev/null
certoraRun certora/conf/clusters-eth-withdraw.conf --compilation_steps_only
certoraRun certora/conf/clusters-eth-withdraw.conf
```

No usar `cat`, `env`, `set -x` ni comandos equivalentes que impriman la key.
No copiarla al repo ni añadirla al log. Los runner `npm run certora:*` ejecutan
también `npm run build`; en esta copia el build puede estar afectado por un test
Kontrol preexistente que importa `forge-std/Test.sol` sin tener `forge-std`
instalado en Hardhat. Si eso ocurre, registrar la limitación y usar los comandos
directos anteriores; no editar ni borrar ese test para forzar el build.

## Limitaciones actuales del modelo

- Liquidación ETH: cuatro operadores ordenados y distintos; snapshots con hasta
  1,000,000 bloques de accrual; fees de operador y red acotados a 1,000,000,000
  raw units; periodo de liquidación hasta 1,000,000 y vUnits explícitos hasta
  100,000,000. El helper independiente omite snapshots inactivos como la ruta
  de ejecución, aunque el constructor de esta regla inicializa los cuatro como
  activos.
- Liquidación SSV: cuatro operadores ordenados y distintos; 1–100 validadores;
  snapshots con hasta 1,000,000 bloques de accrual; fees de operador y red
  acotados a 1,000,000,000 raw units; periodo de liquidación hasta 1,000,000.
- Withdraw ETH: hay una regla de snapshots actuales y otra con hasta 1,000,000
  bloques de accrual, con vUnits base y explícitos desde la base.
- No es una prueba de todo el protocolo. Los helpers inicializan storage
  diamond relevante; no asumir que cubren layouts arbitrarios, migración,
  roots EB, operadores eliminados, reentrancia de receptores o conservación
  global entre todos los módulos.
- El contrato compilado conserva una advertencia Solidity previa: el retorno de
  `SSVViews.getOperatorFee` puede quedar sin asignar. La config Certora ignora
  warnings para compilar el harness; no arreglar código de producción dentro
  de esta tarea sin determinar alcance e impacto por separado.

## Siguiente trabajo recomendado

1. **Probar liquidación de cluster insolvente y contabilidad posterior.** Para
   ETH y SSV por separado, crear un testigo de liquidación exitosa y comprobar
   el cluster inactivo, hash canónico, contadores y distribución/burn de saldo.
   Modelar explícitamente pagos ETH/SSV o acotar la propiedad a estado que no
   requiera llamadas externas sin justificar esos supuestos.
2. **Extender el dominio de operadores.** Evaluar 1, 4, 7, 10 y 13 operadores
   y estados con snapshot activo/inactivo. Evitar transformar todo de una vez:
   mantener un baseline de cuatro y medir timeout/alcance por cada variante.
3. **Propiedad de separación de activos.** Verificar que liquidación/retiro SSV
   no altera balances ETH ni viceversa, usando hashes/observaciones antes y
   después para ambos espacios de almacenamiento.
4. **Migración SSV→ETH.** Antes de formular un invariante amplio, mapear las
   funciones y slots afectados. Probar que no queden derechos de retiro en
   ambos sistemas y que un segundo intento de migración no sea aceptado.
5. **Cruzar con Halmos/Foundry.** Portar primero las obligaciones exitosas de
   liquidación y withdraw; preservar los supuestos y límites de cada herramienta
   y convertir todo contraejemplo formal en regresión determinista.

Para cada nueva regla, separar precondiciones, llamada bajo prueba y oráculo;
documentar supuestos/recortes, incluir testigo de alcanzabilidad, validar la
view contra ejecución donde aplique, y reportar explícitamente si el resultado
es `PASS`, contraejemplo real, artefacto de modelo o timeout/inconcluso.

## Cautelas del workspace

Hay modificaciones preexistentes de HEVM/Kontrol y artefactos no relacionados
en `repos/ssv-network/` (incluidos `foundry.toml`, `hevm/`, `kontrol/`,
`test/hevm/` y `test/kontrol/`). No ejecutar reset/clean global, no revertir
cambios ajenos y no editar esos archivos salvo que una propiedad nueva lo
requiera y se documente claramente. Antes de cerrar, ejecutar `git diff --check`
en el repo del protocolo y revisar `git status --short` para identificar solo
los archivos propios de la tarea.
