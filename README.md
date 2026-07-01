# HydroCel Geodesic EEG — Preprocessing Pipelines

Automated preprocessing pipelines for HydroCel 65-channel EEG data. The repository
contains two pipelines: an **ERP (task) pipeline** that takes raw `.mat` recordings
through event recoding from behavioral data, ASR cleaning, ICA with ICLabel artifact
rejection, and bin-based epoching into final `.erp` files; and a **resting-state
pipeline** that segments eyes-open and eyes-closed periods and cleans each segment with
the same ASR/ICA/ICLabel approach.

## Context

These pipelines were developed to support an undergraduate thesis at Universidad del
Desarrollo (Santiago, Chile). The code is original. The EEG and behavioral data belong
to the original study and are not redistributed here. No citation is available yet; it
will be added once the thesis is published.

## What's in this repo

```
.
├── Processing Scripts/                 # ERP (task) pipeline
│   ├── run_erp_pipeline.m              # Entry point: set paths, run one experiment
│   ├── process_erp_experiment_batch.m  # Batch driver over all .mat files in a folder
│   ├── process_single_erp_subject.m    # Per-subject load → clean → ICA → epoch → ERP
│   └── bins imagenes.txt               # ERPLAB BDF bin definitions (valence/congruence)
├── Resting State Scripts/              # Resting-state pipeline
│   ├── run_hydrocel_pipeline.m         # Entry point: set paths, run one experiment
│   ├── process_hydrocel_batch.m        # Batch driver over all .mat files in a folder
│   └── process_single_hydrocel.m       # Per-subject load → segment → clean → ICA
├── docs/
│   ├── event-recoding.md               # ERP event filtering and recoding scheme
│   ├── parameters.md                   # Filter, ASR, ICA, ICLabel, epoch parameters
│   └── troubleshooting.md              # Common errors and fixes
├── LICENSE
└── README.md
```

### ERP (task) pipeline

Steps: data load and channel labeling (E1–E64, Cz), GSN-HydroCel-65 channel locations,
Cz re-reference, 0.5–35 Hz Butterworth filtering, event import and recoding from
behavioral Excel files, incorrect-trial removal, ASR cleaning, extended Infomax ICA with
ICLabel rejection, bin assignment, epoching (−200 to 800 ms), and ERP averaging. A
region-of-interest channel (E65, mean of channels 33–40) is added to the final ERP. See
`docs/parameters.md` and `docs/event-recoding.md` for details.

### Resting-state pipeline

Steps: data load and channel labeling, channel locations, Cz re-reference, 0.5–35 Hz
Butterworth filtering, and event import. The continuous recording is split into two
resting segments using the `fix1`, `fix2`, and `TRSP` markers: **eyes-open** (`abiertos`,
`fix1`→`fix2`) and **eyes-closed** (`cerrados`, `fix2`→`TRSP`). Each segment is cleaned
with ASR, decomposed with extended Infomax ICA, classified with ICLabel, and has flagged
components removed. ASR/ICA/ICLabel parameters match the ERP pipeline (see
`docs/parameters.md`); the resting-state ICA uses no fixed PCA reduction. Recordings
missing any of `fix1`/`fix2`/`TRSP`, or with markers out of order, are saved to
`problematic_data/` for inspection instead of being segmented.

## How to reproduce

Requirements: MATLAB with EEGLAB and the plugins listed under [Environment](#environment).

1. Install EEGLAB plugins via `File → Manage EEGLAB extensions`: `clean_rawdata`,
   `ICLabel`, `ERPLAB`.
2. Arrange the input data as shown under [Data](#data).

**ERP pipeline** — open `Processing Scripts/run_erp_pipeline.m`, set the paths, and run:

```matlab
experiment_num = 1;                              % 1, 2, or 3
input_dir    = '<path/to>\Data\E1';              % folder with .mat files
behavior_dir = '<path/to>\Conductuales_1';       % folder with behavioral .xlsx
bins_file    = '<path/to>\bins imagenes.txt';
output_dir   = '<path/to>\Processed';
chanLoc_file = '<path/to>\eeglab\...\GSN-HydroCel-65_1.0.sfp';
```

```matlab
run_erp_pipeline
```

Output goes to `output_dir/EX/` in `Cleaned/`, `Set/`, `ERP/`, and `Reports/` (plus
`Problematic/` for files that error). To process all three experiments, repeat with
`experiment_num` and the matching directories set to 2 and 3.

**Resting-state pipeline** — open `Resting State Scripts/run_hydrocel_pipeline.m`, set
the paths, and run:

```matlab
input_dir    = '<path/to>\Mona Lisa RE\Exp 1';
output_dir   = '<path/to>\Mona Lisa RE\Processed\Exp1';
chanLoc_file = '<path/to>\eeglab\...\GSN-HydroCel-65_1.0.sfp';
```

```matlab
run_hydrocel_pipeline
```

Output is `S_XX_ExpY_RE_abiertos.set` and `S_XX_ExpY_RE_cerrados.set` per subject, plus
`processing_log.txt`, `subject_reports/`, and `problematic_data/`.

Both pipelines write a master `processing_log.txt` and a per-subject report for every run.

## Data

The EEG and behavioral data are **not included** in this repository; they belong to the
original study and are not redistributed. The pipelines expect:

```
<path/to>/
├── Data/{E1,E2,E3}/EX_Y YYYYMMDD HHMM.mat   # ERP task recordings (65-channel)
├── Conductuales_{1,2,3}/EX_Y.xlsx           # behavioral data per subject (ERP)
├── Mona Lisa RE/Exp {1,2,3}/EX_YRE_*.mat    # resting-state recordings (65-channel)
└── Processing Scripts/bins imagenes.txt
```

- `.mat` files contain the EEG signal variable ending in `2` (a 65×N matrix) and an
  `ECI_TCPIP_55513` event variable. See `docs/event-recoding.md` for details.
- ERP behavioral `.xlsx` files must include the columns `Correct`, `Correct2`,
  `preg1ACC`, and `preg2ACC`.
- Resting-state recordings must contain `fix1`, `fix2`, and `TRSP` event markers.

## Environment

MATLAB R2024a with:

- EEGLAB 2025.1.0
- ERPLAB 12.01 (bins and ERP averaging)
- `clean_rawdata` plugin (ASR)
- `ICLabel` plugin (ICA component classification)

## Citation

Not available yet. A reference will be added when the supporting thesis is published.

## License

MIT — see the [LICENSE](LICENSE) file.
