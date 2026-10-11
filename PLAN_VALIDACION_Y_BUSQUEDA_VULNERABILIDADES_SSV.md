# Plan de validación y búsqueda de vulnerabilidades — SSV Network

## 1. Objetivo

La campaña debe buscar fallos que puedan producir pérdida o bloqueo de fondos,
liquidaciones incorrectas, crédito sin respaldo, desajustes contables, escalada
de privilegios o corrupción de estado durante el ciclo de vida de operadores,
validadores, clusters y staking.

La validación combinará:

- revisión manual orientada por invariantes;
- tests unitarios, de integración y valores frontera;
- fuzzing con estado mediante Echidna y Foundry;
- ejecución simbólica con Halmos;
- verificación formal focalizada con Certora;
- pruebas de upgrades y estado real mediante fork.

Una suite con alta cobertura no demuestra por sí sola las propiedades
económicas para todas las secuencias y valores. Cada propiedad crítica debe
tener una formulación precisa, un oráculo independiente y, cuando sea viable,
validación con dos herramientas.

## 2. Estado inicial

El repositorio ya contiene:

- tests unitarios e integración de los módulos principales;
- 209 tests E2E documentados como exitosos;
- harnesses Echidna para clusters, contabilidad, operadores, validadores, DAO,
  staking, migración, effective balance y cSSV;
- pruebas simbólicas de liquidación con Halmos, HEVM y Kontrol;
- una prueba Certora completada para liquidación ETH.

La propiedad formal ya demostrada es:

> Un tercero distinto del propietario no puede liquidar un cluster ETH activo y
> solvente dentro del dominio modelado, y el hash almacenado no cambia cuando
> la llamada revierte.

También se confirmó que el propietario puede autoliquidar su cluster. Esta es
una excepción intencional que debe conservarse en las especificaciones.

La prueba actual está limitada a clusters ETH, cuatro operadores ordenados y
distintos, un máximo de 100 validadores y estado construido por el harness. No
constituye una prueba de todo el protocolo.

## 3. Modelo de amenazas

### Actores adversarios

- usuario externo sin permisos;
- propietario malicioso de cluster u operador;
- operador eliminado o con fee en transición;
- contrato receptor que intenta reentrar;
- contrato externo de whitelist malicioso;
- oracle comprometido o grupo de oracles coordinados;
- administrador comprometido;
- usuario de staking que explota redondeos o transferencias de cSSV;
- secuenciador que elige orden, timestamp y separación entre bloques;
- migrador que combina estados legacy SSV y estados ETH.

### Activos protegidos

- ETH y SSV depositados en clusters;
- ganancias de operadores y del DAO;
- pool ETH de staking;
- SSV que respalda el supply de cSSV;
- snapshots, índices, raíces, contadores y effective balances;
- autorización de módulos, proxy y upgrades.

### Impactos prioritarios

1. pérdida o robo de fondos;
2. insolvencia global o local;
3. liquidación incorrecta;
4. doble cobro o doble contabilización;
5. bloqueo permanente de retiros o migraciones;
6. manipulación de fees o recompensas;
7. bypass de permisos, whitelist u oracle quorum;
8. corrupción que aparece después de varios bloques.

## 4. Contratos y propiedades a validar

### 4.1 P0 — Clusters y contabilidad económica

Contratos principales:

- `contracts/modules/SSVClusters.sol`;
- `contracts/libraries/ClusterLib.sol`;
- `contracts/libraries/OperatorLib.sol`;
- `contracts/libraries/ProtocolLib.sol`;
- `contracts/libraries/SSVPackedLib.sol`;
- storage de protocolo, clusters y effective balance.

Invariantes de autorización y liquidación:

- un tercero no puede liquidar un cluster ETH o SSV solvente;
- un cluster insolvente y activo puede liquidarse;
- un cluster inactivo no puede liquidarse nuevamente;
- una liquidación fallida no modifica balances, índices, contadores ni hashes;
- la autoliquidación conserva la semántica prevista;
- un receptor malicioso no puede reentrar y repetir la liquidación;
- `SSVViews.isLiquidatable*` coincide con la ruta ejecutable para el mismo
  estado.

Invariantes de conservación y solvencia:

- el ETH del contrato cubre balances de clusters, ganancias de operadores,
  ganancias del DAO y obligaciones del pool de staking;
- el SSV cubre clusters legacy, ganancias y retiros pendientes;
- ningún retiro crea valor ni afecta pasivos de otro activo;
- una liquidación redistribuye valor sin crearlo ni destruirlo fuera de los
  fees modelados;
- el balance de un cluster no aumenta por el mero paso del tiempo;
- el cobro desde el último settlement coincide con un cálculo independiente de
  fee de red y fees de operadores ponderados por validator count/vUnits.

Invariantes de estado:

- el hash almacenado corresponde exactamente al estado emitido;
- un cluster activo tiene índices compatibles con el bloque actual;
- liquidar deja el estado canónico y actualiza los contadores una sola vez;
- reactivar solo parte de un estado liquidado y restaura una sola vez contadores
  y desviaciones;
- `deposit` no altera contadores, fees devengados ni autorización;
- `withdraw` no deja un cluster activo por debajo de su umbral;
- ciclos liquidate/reactivate no acumulan ni restan dos veces vUnits.

Invariantes de effective balance:

- vUnits implícitos equivalen a `validatorCount * BPS_DENOMINATOR`;
- vUnits explícitos respetan los límites derivados del EB;
- las variaciones por operador suman las desviaciones de sus clusters activos;
- `daoTotalEthVUnits` coincide con el agregado global;
- el settlement previo a un cambio EB usa los vUnits anteriores;
- una actualización sobre un cluster inactivo no reactiva contabilidad;
- EB mínimo/máximo, cero validadores y valores extremos no provocan overflow,
  underflow o truncamiento silencioso.

Pruebas sugeridas:

1. Certora para liquidación SSV, retiro solvente y conservación de hashes.
2. Halmos para las mismas propiedades con vUnits implícitos y explícitos.
3. Echidna con secuencias deposit/withdraw/register/remove/EB update/liquidate/
   reactivate.
4. Foundry invariant con handlers multiusuario y ghost variables contables.
5. Tests diferenciales entre `SSVViews` y un modelo matemático independiente.
6. Matrices para 1, 4, 7, 10 y 13 operadores; 0, 1 y máximos de validadores;
   EB mínimo, habitual y máximo.
7. Búsqueda dirigida en casts y operaciones de packing.

### 4.2 P0 — Validadores y migración

Contratos:

- `contracts/modules/SSVValidators.sol`;
- `contracts/libraries/ValidatorLib.sol`;
- rutas de migración de `SSVClusters.sol`.

Invariantes:

- una public key no puede registrarse dos veces para la identidad definida;
- registro y eliminación actualizan una sola vez todos los validator counts;
- contadores de operador, cluster y DAO permanecen reconciliados;
- las listas de operadores cumplen longitud, orden, unicidad y existencia;
- un operador privado solo acepta propietarios autorizados;
- bulk y single producen el mismo estado final;
- un fallo intermedio en bulk revierte la operación completa;
- la eliminación liquida fees hasta el bloque correcto;
- migrar SSV a ETH es de una sola vía y no deja saldo reclamable en ambos
  sistemas;
- EB explícito, operadores eliminados y clusters liquidados no causan doble suma
  o doble resta;
- no se puede repetir una migración ni usar un struct obsoleto del cluster.

Pruebas sugeridas:

- fuzz diferencial single frente a bulk;
- claves duplicadas en distintas posiciones;
- operador eliminado antes y después de liquidar;
- migración con balance cero, dust, máximo y fees acumulados;
- migración antes/después de EB updates y cambios de fee;
- replay de snapshots y estados antiguos;
- whitelist contracts que revierten, consumen gas o reentran.

### 4.3 P1 — Operadores y fees

Contratos:

- `contracts/modules/SSVOperators.sol`;
- `contracts/modules/SSVOperatorsWhitelist.sol`;
- `contracts/libraries/OperatorLib.sol`.

Invariantes:

- solo el owner modifica privacidad, whitelist y fee;
- las public keys activas son únicas y los IDs no se reutilizan;
- un fee está en cero o entre mínimo y máximo;
- declarar un fee no lo aplica antes de tiempo;
- ejecutar solo funciona dentro de la ventana y con parámetros aún válidos;
- reducir un fee nunca lo aumenta;
- retirar ETH no modifica ganancias SSV y viceversa;
- no puede retirarse más de lo devengado;
- retirar todo deja cero sin perder dust contabilizado;
- remover un operador no permite un segundo cobro ni reutilizar solicitudes de
  fee antiguas;
- cambios de fee afectan clusters compartidos desde el bloque exacto, sin efecto
  retroactivo.

Pruebas sugeridas:

- fronteras `begin-1`, `begin`, `end`, `end+1`;
- cambios de mínimo/máximo entre declare y execute;
- clusters compartiendo operadores con EB distintos;
- receptores reentrantes;
- remove/re-register y declaraciones antiguas;
- alternancia de fees y retiros ETH/SSV.

### 4.4 P1 — DAO, oracles y raíces EB

Contratos:

- `contracts/modules/SSVDAO.sol`;
- `contracts/libraries/ProtocolLib.sol`;
- storage de protocolo, EB y staking.

Invariantes:

- solo rutas autorizadas modifican parámetros;
- fees, collateral, quorum y periodos respetan sus límites;
- un oracle no vota dos veces por el mismo compromiso;
- una raíz solo se finaliza con quorum real sobre el supply congelado;
- cambios de supply no alteran retroactivamente el quorum;
- block numbers son monotónicos, no futuros y no obsoletos;
- reemplazar oracles mantiene mappings y pesos consistentes;
- finalizar limpia el estado temporal de la ronda;
- una prueba Merkle solo sirve para el cluster, balance y bloque comprometidos;
- no existe replay cross-cluster o cross-root;
- el DAO no retira más de sus ganancias.

Pruebas sugeridas:

- pesos con división no exacta y dust alrededor del quorum;
- supply menor al número de oracles;
- raíces competidoras con subconjuntos superpuestos;
- reemplazo de oracle durante una ronda;
- misma raíz con otro block number;
- mutación de cada campo y nodo del proof;
- fronteras de frecuencia y staleness.

### 4.5 P1 — Staking y cSSV

Contratos:

- `contracts/modules/SSVStaking.sol`;
- `contracts/token/CSSVToken.sol`;
- `contracts/libraries/storage/SSVStorageStaking.sol`.

Invariantes:

- `totalSupply(cSSV)` no excede el SSV bloqueado que lo respalda;
- mint y burn solo pueden ejecutarse desde staking;
- stake, requestUnstake y withdrawUnlocked conservan el SSV total;
- una solicitud no se retira antes del cooldown ni más de una vez;
- staked + pending concuerda con los activos correspondientes;
- las recompensas reclamables no superan el pool ETH;
- reclamar dos veces sin nuevo accrual no produce segundo pago;
- transferir cSSV liquida correctamente emisor y receptor;
- no se transfieren recompensas históricas gratis al comprador;
- redondeos dejan dust acotado y no extraíble repetidamente;
- el límite de solicitudes no crea un DoS irreversible;
- tokens o receptores maliciosos no rompen la contabilidad.

Pruebas sugeridas:

- tres usuarios alternando stake, transfer, claim y unstake;
- cantidades alrededor del mínimo, dust y máximos;
- transferencias pequeñas repetidas para amplificar redondeos;
- variaciones de earnings entre sincronizaciones;
- límite de solicitudes pendientes;
- callbacks maliciosos de token y receptores ETH.

### 4.6 P1 — Proxy, módulos y upgrades

Contratos:

- `contracts/SSVNetwork.sol`;
- `contracts/SSVProxy.sol`;
- `contracts/upgrades/`;
- inicializadores y storage libraries.

Invariantes:

- implementaciones e inicializadores no pueden tomarse directamente;
- solo el owner autoriza upgrades y cambios administrativos;
- cada selector delega al módulo correcto;
- `msg.sender`, `msg.value` y revert data se conservan;
- un módulo no sobrescribe slots de otro;
- el layout antes y después de un upgrade es compatible;
- no quedan módulos en address cero o sin código;
- un upgrade no reinicializa balances, owners, oracles o guardas;
- el fallback de views no expone una ruta mutadora inesperada.

Pruebas sugeridas:

- fork del deployment real antes/después del upgrade;
- snapshot y comparación bit a bit de slots críticos;
- implementación maliciosa y caller no autorizado;
- inicialización repetida y llamadas directas;
- selector collisions y calldata malformada;
- verificación automática del storage layout en CI.

## 5. Hipótesis concretas de vulnerabilidad

1. Diferencia entre `isLiquidatable` y la liquidación ejecutable.
2. Settlement con vUnits nuevos cuando correspondían los anteriores.
3. Doble desviación EB en register/remove/reactivate/migrate.
4. Snapshot obsoleto aceptado después de cambiar fee o eliminar operador.
5. Truncamiento packed que reduce fees o collateral.
6. Overflow intermedio aunque el resultado final quepa.
7. Retiro que evalúa solvencia antes de actualizar índices.
8. Migración con derechos de cobro simultáneos en SSV y ETH.
9. Reentrancia cruzada entre módulos con guardas inconsistentes.
10. Reutilización de fee-change requests tras remove/re-register.
11. Quorum incorrecto por dust o supply congelado truncado.
12. Replay de prueba EB para otro cluster, root o bloque.
13. Transferencia cSSV que mueve recompensas ya devengadas.
14. Dust extraíble mediante ciclos pequeños y repetidos.
15. Corrupción de storage o toma de control por inicialización/upgrade.

## 6. Estrategia por herramienta

### Tests deterministas

Usarlos para valores frontera y transiciones concretas. Todo contraejemplo de
fuzzing o prueba formal debe convertirse en una regresión pequeña.

### Foundry fuzz/invariant

Crear handlers con múltiples actores y ghost variables para fondos, liabilities,
validator counts, vUnits y backing de cSSV. El oráculo no debe reutilizar la
misma función del contrato que se está validando.

### Echidna

Extender los harnesses con secuencias largas, múltiples clusters, operadores
compartidos y cambios administrativos intercalados. Ejecutar campañas rápidas
por PR y campañas profundas con corpus persistente.

### Halmos

Usarlo para propiedades universales acotadas: liquidación, retiros, packing,
ventanas temporales y equivalencia entre rutas. Agregar checks de alcanzabilidad
para evitar pruebas vacuas.

### Certora

Priorizar:

- liquidación SSV;
- withdraw preserva solvencia;
- conservación contable por operación;
- register/remove mantienen contadores;
- migración de una sola vía;
- separación ETH/SSV;
- backing staking/cSSV.

Cada spec debe documentar supuestos, límites, métodos resumidos y storage
inicializado. Cada regla universal debe acompañarse de `satisfy` o un witness
concreto.

### Fork testing

Repetir propiedades críticas sobre estado desplegado, especialmente upgrades,
migración, operadores eliminados, clusters legacy y oracles. El fork valida
compatibilidad de estado, pero no reemplaza la prueba formal.

## 7. Roadmap

### Fase 0 — Baseline reproducible (1–2 días)

- fijar commit, herramientas y compiladores;
- ejecutar build, unit, integration, E2E y sanity;
- clasificar fallos preexistentes;
- ejecutar todos los harnesses Echidna;
- reproducir Certora y ports simbólicos;
- guardar comandos, seeds, tiempos y resultados.

Salida: baseline verde o excepciones explícitas.

### Fase 1 — Mapa de estado y contabilidad (2–4 días)

- documentar cada saldo, índice, snapshot y contador;
- identificar quién lo incrementa, reduce y liquida;
- modelar flujos ETH, SSV, cSSV y vUnits;
- construir un modelo matemático independiente;
- marcar casts, packing, `unchecked` y llamadas externas.

Salida: catálogo de invariantes y matriz función → estado afectado.

### Fase 2 — Clusters ETH y EB (1 semana)

- ampliar la prueba formal de liquidación;
- demostrar seguridad de withdraw;
- comparar views con ejecución;
- fuzzear EB, roots, staleness y tamaños de cluster;
- atacar liquidate/reactivate y operadores eliminados.

Salida: propiedades P0 ETH validadas con dos técnicas.

### Fase 3 — Legacy SSV y migración (4–6 días)

- formalizar liquidación SSV;
- probar separación de activos;
- validar migración de una sola vía;
- explorar estados legacy mediante fork;
- combinar EB explícito y operadores eliminados.

Salida: ninguna secuencia conserva derechos de cobro en ambos sistemas.

### Fase 4 — Operadores, validadores y whitelist (1 semana)

- equivalencia single/bulk;
- contadores globales y por operador;
- fees y ventanas temporales;
- callbacks y whitelist contracts hostiles;
- remove/re-register y clusters compartidos.

Salida: reconciliación exacta tras secuencias arbitrarias acotadas.

### Fase 5 — DAO, oracles y Merkle proofs (4–6 días)

- quorum, pesos y dust;
- roots competidoras y cambios de oracle;
- monotonicidad;
- domain separation y replay;
- efecto de cambios administrativos sobre clusters existentes.

Salida: solo un quorum válido publica el dato del cluster correcto.

### Fase 6 — Staking y cSSV (1 semana)

- backing y supply;
- reward accounting multiusuario;
- transferencias y claims;
- cooldown y retiros pendientes;
- dust y reentrancia.

Salida: solvencia y conservación para secuencias acotadas de actores.

### Fase 7 — Proxy, upgrades y fork (3–5 días)

- validar storage layout;
- control de inicialización y upgrades;
- selector routing;
- replay del upgrade con estado real;
- smoke tests post-upgrade de operaciones P0.

Salida: storage y liabilities iguales salvo cambios documentados.

### Fase 8 — Triangulación y reporte (2–4 días)

- minimizar cada hallazgo;
- confirmar impacto y alcanzabilidad;
- validar con una segunda herramienta;
- crear test de regresión;
- verificar el parche contra todas las invariantes;
- publicar matriz propiedad → evidencia → resultado → limitaciones.

## 8. Severidad

- Crítico: robo, insolvencia, mint sin respaldo o upgrade no autorizado.
- Alto: liquidación errónea, doble cobro, bloqueo general o quorum bypass.
- Medio: pérdida acotada por redondeo, DoS parcial o corrupción recuperable.
- Bajo: inconsistencia de views/eventos sin impacto económico directo.
- Informativo: claridad, gas o defensa en profundidad.

La severidad debe considerar precondiciones, capital requerido, repetibilidad,
capacidad de extracción, afectados y posibilidad de recuperación.

## 9. Criterios de finalización

- todas las propiedades P0 tienen evidencia reproducible;
- cada prueba formal incluye chequeo de no vacuidad;
- los invariantes contables usan un oráculo independiente;
- campañas profundas de fuzzing no producen casos nuevos;
- cada hallazgo confirmado tiene test de regresión;
- upgrades se prueban en fork con estado representativo;
- las limitaciones de cada herramienta están documentadas;
- existe una matriz de contratos, funciones, invariantes y riesgos.

## 10. Primer backlog recomendado

1. Formalizar `thirdPartyCannotLiquidateSolventSSV`.
2. Demostrar que `withdraw` no deja un cluster ETH activo e insolvente.
3. Probar equivalencia entre views y ejecución para ETH y SSV.
4. Crear invariant handler multi-cluster para conservación ETH/SSV.
5. Atacar EB update → fee change → remove operator → liquidate/reactivate.
6. Formalizar que migración elimina todo derecho de cobro legacy.
7. Probar quorum con dust, reemplazo de oracle y roots competidoras.
8. Modelar backing cSSV y rewards con tres usuarios.
9. Ejecutar storage-layout diff y fork de upgrade.
10. Consolidar contraejemplos en una suite rápida de CI.
