# ERP Experiment Processing Pipeline

## Descripción General

Pipeline automatizado para procesar experimentos de ERPs con datos de HydroCel (65 canales) que incluye:

- ✅ Procesamiento en batch automático (sin intervención manual)
- ✅ Importación y etiquetado de eventos desde datos conductuales
- ✅ Filtrado y recodificación de eventos según valencia y congruencia
- ✅ Eliminación automática de trials incorrectos
- ✅ Limpieza automática con ASR
- ✅ ICA automático con rechazo de artefactos mediante ICLabel
- ✅ Creación de bins y segmentación en épocas
- ✅ Generación automática de ERPs
- ✅ Logs detallados por sujeto

## Estructura del Pipeline

```
1. Carga de datos .mat
2. Etiquetado de canales (E1-E64, Cz)
3. Localización de canales (GSN-HydroCel-65)
4. Re-referencia a Cz
5. Filtrado (0.5-35 Hz, Butterworth orden 2)
6. Importación de eventos desde ECI_TCPIP_55513
7. Filtrado de eventos (solo 'imag' y 'TRSP')
8. Renombrado de TRSP → TRSP1, TRSP2
9. Matching con datos conductuales (Excel)
10. Recodificación de eventos:
    - 'imag' → valencia + congruencia (ej: 11, 12, 13, 21, 22, 23)
    - 'TRSP1' → 100, 200, 300 (según valencia)
    - 'TRSP2' → 1000, 2000 (según congruencia)
11. Eliminación de trials incorrectos
12. Limpieza automática (ASR)
13. ICA (extended Infomax, PCA=64)
14. Clasificación con ICLabel y rechazo automático
15. Creación de event list
16. Asignación de bins
17. Segmentación en épocas (-200 a 800 ms, baseline -200 a 0)
18. Promediado de épocas → ERP
19. Creación de canal E65 (promedio de canales 33-40)
20. Guardado de 3 archivos: cleaned, epoched, erp
```

## Archivos del Pipeline

### Principales
- `run_erp_pipeline.m` - Script principal de ejecución
- `process_erp_experiment_batch.m` - Función de procesamiento en batch
- `process_single_erp_subject.m` - Función de procesamiento individual

### Dependencias
- EEGLAB (2024.0 o superior)
- Plugin: Clean_rawdata (ASR)
- Plugin: ICLabel (clasificación ICA)
- Plugin: ERPLAB (bins y ERPs)

## Instalación

1. Instala EEGLAB y los plugins necesarios:
   ```
   File → Manage EEGLAB extensions
   - Clean_rawdata
   - ICLabel
   - ERPLAB
   ```

2. Copia los 3 archivos .m a tu carpeta de proyecto

3. Crea el archivo `bins_imagenes.txt` con tus definiciones de bins

## Uso

### Estructura de Directorios Requerida

```
Proyecto/
├── Data/
│   ├── E1/
│   │   ├── E1_1 20240305 1123.mat
│   │   ├── E1_2 20240307 1737.mat
│   │   └── ...
│   ├── E2/
│   └── E3/
├── Conductuales_1/
│   ├── E1_1.xlsx
│   ├── E1_2.xlsx
│   └── ...
├── Conductuales_2/
├── Conductuales_3/
└── bins_imagenes.txt
```

### Formato de Archivos de Entrada

**Archivos .mat**:
- Nombre: `EX_Y YYYYMMDD HHMM.mat` (con espacios)
  - Ejemplo: `E1_3 20240308 1109.mat`
- Variables dentro:
  - **Señal EEG** (SIEMPRE usar la que termina en "2"):
    - `EX_Y_YYYYMMDD_HHMM2` ← **ESTA ES LA CORRECTA**
    - `EX_Y_YYYYMMDD_HHMM1` ← Ignorar (no usar)
    - Ejemplo correcto: `E1_3_20240308_11092`
    - Ejemplo ignorado: `E1_3_20240308_11091`
    - Estructura: matriz 65×N (65 canales × N muestras)
  - **Eventos**: `ECI_TCPIP_55513` (siempre se llama igual)
    - Fila 1: tipos de eventos (cell array)
    - Fila 4: latencias/frames (números)
  - Otras variables ignoradas: `Impedances_0`, `samplingRate`

**IMPORTANTE**: El nombre de la variable de señal tiene números "pseudo-aleatorios" en medio (timestamp), pero SIEMPRE hay que elegir la que termina en "2", no la que termina en "1".

**Archivos Excel** (conductuales):
- Nombre: `EX_Y.xlsx` (sin timestamp, sin espacios)
  - Ejemplos: `E1_1.xlsx`, `E1_3.xlsx`, `E2_8.xlsx`
- Columnas requeridas:
  - `Correct` - Valencia (1, 2, 3)
  - `Correct2` - Congruencia (1, 2)
  - `preg1ACC` - Accuracy pregunta 1 (0, 1)
  - `preg2ACC` - Accuracy pregunta 2 (0, 1)

**Archivo bins_imagenes.txt**:
- Formato ERPLAB BDF
- Define bins para análisis de ERPs
- Mismo archivo para E1, E2, y E3

### Configuración y Ejecución

1. Abre `run_erp_pipeline.m`

2. Configura los parámetros:

```matlab
% Selecciona experimento (1, 2, o 3)
experiment_num = 1;

% Carpeta con archivos .mat
input_dir = 'D:\Mona Lisa EEG\Data\E1';

% Carpeta con archivos conductuales
behavior_dir = 'D:\Mona Lisa EEG\Conductuales_1';

% Archivo de bins
bins_file = 'D:\Mona Lisa EEG\bins_imagenes.txt';

% Carpeta de salida
output_dir = 'D:\Mona Lisa EEG\Processed';

% Archivo de localizaciones
chanLoc_file = 'C:\...\GSN-HydroCel-65_1.0.sfp';
```

3. Ejecuta:
```matlab
run_erp_pipeline
```

### Estructura de Salida

```
Processed/
└── E1/                          (o E2, E3)
    ├── Cleaned/                 Archivos limpios (post-ICA)
    │   ├── S_01_E1_clean.set
    │   ├── S_02_E1_clean.set
    │   └── ...
    ├── Set/                     Archivos con épocas
    │   ├── S_01_E1.set
    │   ├── S_02_E1.set
    │   └── ...
    ├── ERP/                     Archivos ERP
    │   ├── S_01_E1.erp
    │   ├── S_02_E1.erp
    │   └── ...
    ├── Reports/                 Logs y reportes
    │   ├── S_01_E1_report.txt
    │   ├── S_02_E1_report.txt
    │   └── processing_log.txt
    └── Problematic/            Archivos con errores
```

## Recodificación de Eventos

### Eventos 'imag' (estímulos)
```
Valencia (Correct):  1, 2, 3
Congruencia (Correct2): 1, 2

Recodificación:
  congruencia * 10 + valencia

Ejemplos:
  Congruencia=1, Valencia=1 → '11'
  Congruencia=1, Valencia=2 → '12'
  Congruencia=1, Valencia=3 → '13'
  Congruencia=2, Valencia=1 → '21'
  Congruencia=2, Valencia=2 → '22'
  Congruencia=2, Valencia=3 → '23'
```

### Eventos TRSP1 (respuesta 1)
```
Valencia (Correct): 1, 2, 3

Recodificación:
  valencia * 100

Ejemplos:
  Valencia=1 → '100'
  Valencia=2 → '200'
  Valencia=3 → '300'
```

### Eventos TRSP2 (respuesta 2)
```
Congruencia (Correct2): 1, 2

Recodificación:
  congruencia * 1000

Ejemplos:
  Congruencia=1 → '1000'
  Congruencia=2 → '2000'
```

### Eliminación de Trials Incorrectos

Se eliminan eventos donde:
- TRSP1 con `preg1ACC = 0` (respuesta incorrecta)
- TRSP2 con `preg2ACC = 0` (respuesta incorrecta)

## Información en los Logs

### Log Maestro (`processing_log.txt`)
```
=== ERP Experiment 1 Processing Log ===
Date: 20-Nov-2025 14:30:00
Input Directory: D:\Mona Lisa EEG\Data\E1
...

[SUCCESS] E1_1 20240305 1123.mat - Completed: S_01_E1_clean.set, S_01_E1.set, S_01_E1.erp
[FAILED]  E1_2 20240307 1737.mat - No behavioral file found
...

=== FINAL SUMMARY ===
Total files: 43
Successful: 41
Failed: 2
Success rate: 95.3%
```

### Reportes Individuales

Cada `S_XX_EX_report.txt` contiene:

1. **Carga de datos**: Variables encontradas, tamaño
2. **Eventos originales**: Tipos y cantidades
3. **Filtrado de eventos**: imag, TRSP1, TRSP2
4. **Matching conductual**: Archivo usado, eventos recodificados
5. **Trials eliminados**: Por respuestas incorrectas
6. **Limpieza ASR**: Samples removidos (número y %)
7. **ICA**: Componentes computados y rechazados con clasificaciones
8. **Bins y épocas**: Número de épocas finales
9. **Archivos guardados**: Cleaned, Set, ERP

Ejemplo:
```
=== Processing Report: S_01_E1 ===

--- STEP 6: Event Processing ---
Total events imported: 487
Event types: SESS, CELL, bgin, imag, TRSP, fix1, fix2
After filtering (imag + TRSP): 360
Event counts: imag=120, TRSP1=120, TRSP2=120

--- STEP 7: Behavioral Data Matching ---
Behavioral file: E1_1.xlsx
Recoded 120 "imag" events
Recoded TRSP1: 120, TRSP2: 120
Removed 24 incorrect trials
Final event count: 336
Final event types: 11, 12, 13, 21, 22, 23, 100, 200, 300, 1000, 2000

--- STEP 8: Artifact Removal ---
[Clean] ASR artifact rejection:
  Samples removed: 3254 (0.52%)

[ICA] Extended Infomax:
  ICA complete: 64 components

[ICLabel] Classification:
  Components flagged: 7/64
  Rejected indices: [2 5 8 15 23 31 42]
    Comp 2: Eye (91.2%)
    Comp 5: Muscle (78.5%)
    Comp 8: Eye (85.7%)
    ...

--- STEP 9: Bins & ERPs ---
Event list created
Bins assigned from: bins_imagenes.txt
Epochs extracted: 112 epochs

=== PROCESSING SUMMARY ===
Status: SUCCESS
Final epochs: 112
```

## Parámetros de Procesamiento

### Filtro
```matlab
Butterworth, orden 2
0.5-35 Hz (pasabanda)
Canales: 1-64 (excluye Cz)
```

### ASR (Clean_rawdata)
```matlab
'BurstCriterion': 20
'WindowCriterion': 0.25
'WindowCriterionTolerances': [-Inf 7]
'BurstRejection': 'on'
'Distance': 'Euclidian'
```

### ICA
```matlab
Algoritmo: Extended Infomax
PCA: 64 componentes
```

### ICLabel - Rechazo Automático
Rechaza componentes con ≥70% probabilidad de:
- Músculo
- Ojo
- Corazón
- Ruido de canal

### Épocas
```matlab
Ventana: -200 a 800 ms
Baseline: -200 a 0 ms
```

### Canal Promedio E65
Se crea un canal adicional E65 que es el promedio de 8 canales:
```matlab
E65 = (ch33 + ch34 + ch35 + ch36 + ch37 + ch38 + ch39 + ch40) / 8
```
Este canal se agrega al archivo ERP final para análisis de región de interés.

## Manejo de Errores

### Archivo Conductual No Encontrado
```
ERROR: No behavioral file found matching: *E1_5.xlsx
→ Sujeto no procesado, continúa con siguiente
```

### Columnas Faltantes en Excel
```
ERROR: Required columns not found in behavioral file
→ Verifica: Correct, Correct2, preg1ACC, preg2ACC
```

### Archivo de Bins No Encontrado
```
ERROR: Bins file not found: bins_imagenes.txt
→ Crea el archivo BDF con definiciones de bins
```

### Variable EEG No Encontrada
```
ERROR: Cannot find EEG data variable. Expected: E1_1_20240305_11232
→ Verifica nombre de variable en .mat
```

## Modificar Parámetros

### Cambiar Umbrales de ICLabel
En `process_single_erp_subject.m`, función `clean_and_ica_continuous`:
```matlab
% Línea ~470
EEG = pop_icflag(EEG, [NaN NaN; 0.7 1; 0.7 1; 0.7 1; NaN NaN; 0.7 1; NaN NaN]);
%                                ^^^    ^^^    ^^^              ^^^
%                              Muscle   Eye   Heart         ChanNoise
% Cambiar 0.7 a 0.8 para ser más conservador
% Cambiar 0.7 a 0.5 para ser más agresivo
```

### Cambiar Ventana de Épocas
En `process_single_erp_subject.m`:
```matlab
% Línea ~360
EEG = pop_epochbin(EEG, [-200.0 800.0], [-200 0]);
%                        ^^^^^^  ^^^^   ^^^^^^^^
%                        inicio  fin    baseline
```

### Cambiar Criterios de ASR
En `process_single_erp_subject.m`, función `clean_and_ica_continuous`:
```matlab
% Línea ~420
EEG = pop_clean_rawdata(EEG, ...
    'BurstCriterion', 20, ...     % Aumentar para ser más permisivo
    'WindowCriterion', 0.25, ...
    ...
```

## Solución de Problemas

### "No behavioral file found"
- Verifica que el archivo Excel esté en `behavior_dir`
- Confirma que el nombre sea: `EX_Y.xlsx` (sin espacios en la fecha)
- Ejemplo: `E1_1.xlsx`, `E2_8.xlsx`

### "Required columns not found"
- Abre el Excel y verifica que tenga las columnas:
  - `Correct`
  - `Correct2`
  - `preg1ACC`
  - `preg2ACC`
- Los nombres deben coincidir exactamente (case-sensitive)

### "Bins file not found"
- Verifica la ruta en `bins_file`
- Asegúrate que el archivo exista y tenga formato ERPLAB BDF

### Pocos eventos después de filtrado
- Revisa los valores en las columnas `preg1ACC` y `preg2ACC`
- Si muchos trials tienen 0, se eliminarán automáticamente
- Esto es normal si el participante tuvo bajo desempeño

### ICA toma mucho tiempo
- Normal: ~10-20 minutos por sujeto con ~600,000 samples
- Para acelerar: implementar `parpool_ICA` (próximo paso)

## Procesando Múltiples Experimentos

Para procesar los 3 experimentos secuencialmente:

```matlab
% Experimento 1
experiment_num = 1;
input_dir = 'D:\Mona Lisa EEG\Data\E1';
behavior_dir = 'D:\Mona Lisa EEG\Conductuales_1';
run_erp_pipeline;

% Experimento 2
experiment_num = 2;
input_dir = 'D:\Mona Lisa EEG\Data\E2';
behavior_dir = 'D:\Mona Lisa EEG\Conductuales_2';
run_erp_pipeline;

% Experimento 3
experiment_num = 3;
input_dir = 'D:\Mona Lisa EEG\Data\E3';
behavior_dir = 'D:\Mona Lisa EEG\Conductuales_3';
run_erp_pipeline;
```

