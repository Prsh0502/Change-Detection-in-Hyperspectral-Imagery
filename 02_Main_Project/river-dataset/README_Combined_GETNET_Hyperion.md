# Hyperspectral Change Detection Projects

This repository contains two hyperspectral change-detection projects implemented using MATLAB. The projects use different bitemporal hyperspectral datasets representing different geographic and land-cover environments:

1. **GETNET River Dataset** — river-region change detection
2. **Hyperion Irrigated Agricultural Dataset** — agricultural-area change detection

Both projects investigate binary and/or multi-class change detection between hyperspectral images acquired at different dates.

---

# 1. GETNET River Dataset

## Overview

The GETNET River project performs hyperspectral change detection using a pair of bitemporal hyperspectral images and a binary ground-truth reference map.

The pipeline follows:

**Pseudo-binary detection → Endmember extraction → Hierarchical clustering → Spectral matching → Ambiguity resolution**

## Dataset Description

- **Dataset:** GETNET River Dataset
- **Image dimensions:** 463 × 241 pixels
- **Spectral bands:** 198
- **Ground-truth classes:** Change and No-Change
- **Change pixels:** 9,698
- **No-change pixels:** 101,885
- **Total pixels:** 111,583

The major land-cover changes in this scenario are associated with shifting sediment/sandbar exposure and water level between the two acquisition dates.

## Input Files

The dataset is provided in MATLAB `.mat` format.

Required files:

```text
river_before.mat
river_after.mat
groundtruth.mat
```

The raw hyperspectral cubes are not included in the repository because they exceed GitHub's 100 MB file-size limit.

### Dataset Download

GETNET dataset:

https://drive.google.com/file/d/1cWy6KqE0rymSk5-ytqr7wM1yLMKLukfP/view

Place the downloaded files in:

```text
data/
```

## Methodology

```text
Bitemporal Hyperspectral Images
            ↓
Pseudo-Binary Detection
        (CVA + Otsu)
            ↓
Endmember Extraction
            ↓
Hierarchical Clustering
            ↓
Spectral Matching
            ↓
Ambiguity Resolution
            ↓
Final Change Map
            ↓
Evaluation
```

## Results

| Method | Overall Accuracy (OA) | Precision | Recall | F1 | Kappa |
|---|---:|---:|---:|---:|---:|
| Pseudo-binary (CVA + Otsu) | 75.19% | 0.244 | 0.887 | 0.383 | 0.286 |
| Final (Endmember + SAM + ambiguity resolution) | 85.39% | 0.302 | 0.521 | 0.382 | 0.306 |

## Figures

Typical project outputs include:

- Before image
- After image
- Ground-truth change map
- Detected change map
- Detection/accuracy visualization

Example files:

```text
results/before_after_groundtruth.png
results/detection_accuracy_overlay.png
```

---

# 2. Hyperion Irrigated Agricultural Dataset

## Overview

The Hyperion project performs binary and multi-class hyperspectral change detection using bitemporal Hyperion images acquired over irrigated agricultural land.

## Dataset Description

- **Sensor:** Hyperion on board the EO-1 satellite
- **Study area:** Benton County, Oregon, USA
- **Acquisition dates:** May 1, 2004 and May 8, 2007
- **Image dimensions:** 180 × 225 pixels
- **Original bands:** 242
- **Selected bands after preprocessing:** 159

The selected bands are:

```text
8–57
82–119
131–164
182–184
187–220
```

Preprocessing included:

- Repairing bad stripes
- Removal of uncalibrated and noisiest bands
- Atmospheric correction
- Co-registration

The major land-cover changes are associated with transitions among different crops, soil, and other land-cover types.

## Input Files

The dataset files are provided in MATLAB `.mat` format.

Required files:

```text
PreImg_2004.mat
PostImg_2007.mat
Reference_Map_Binary.mat
Reference_Map_Multiclass.mat
```

### Ground-Truth Maps

**Binary reference map**

Contains two classes:

- Change
- No-change

**Multiclass reference map**

Contains seven classes:

- Change Class 1 (C1)
- Change Class 2 (C2)
- Change Class 3 (C3)
- Change Class 4 (C4)
- Change Class 5 (C5)
- Change Class 6 (C6)
- No-change Class (NC)

## Class Information

| Class | Pixels |
|---|---:|
| Change Class 1 (C1) | 1,034 |
| Change Class 2 (C2) | 1,048 |
| Change Class 3 (C3) | 5,111 |
| Change Class 4 (C4) | 1,261 |
| Change Class 5 (C5) | 479 |
| Change Class 6 (C6) | 988 |
| No-change Class (NC) | 30,579 |
| **Total** | **40,500** |

---

# 3. Project Structure

A combined repository can be organized as:

```text
Change-Detection-in-Hyperspectral-Imagery/
│
├── README.md
├── LICENSE
├── .gitignore
│
├── GETNET_River/
│   ├── main.m
│   ├── src/
│   ├── data/
│   ├── results/
│   └── docs/
│
└── Hyperion_Agricultural/
    ├── main.m
    ├── src/
    ├── data/
    ├── results/
    └── docs/
```

Each project should have its own main entry point so that a reviewer can run the projects independently.

---

# 4. MATLAB Requirements

The projects are MATLAB-based.

The GETNET River implementation uses the **Image Processing Toolbox Hyperspectral Imaging Library**.

Additional MATLAB toolboxes or third-party dependencies should be listed in the individual project folder if required by the implementation.

---

# 5. Running the Projects

## GETNET River

1. Download the required GETNET dataset.
2. Place the `.mat` files in the River project's `data/` folder.
3. Open the project in MATLAB.
4. Run the project's `main.m`.

## Hyperion Agricultural

1. Obtain the required Hyperion dataset files.
2. Place the `.mat` files in the Agricultural project's `data/` folder.
3. Open the project in MATLAB.
4. Run the project's `main.m`.

Both projects should use relative paths rather than machine-specific absolute paths.

Example:

```matlab
projectRoot = fileparts(mfilename("fullpath"));
dataDir = fullfile(projectRoot, "data");
```

---

# 6. Comparison of the Two Projects

| Feature | GETNET River | Hyperion Agricultural |
|---|---|---|
| Environment | River region | Irrigated agricultural area |
| Sensor/Dataset | GETNET River Dataset | Hyperion / EO-1 |
| Image size | 463 × 241 | 180 × 225 |
| Spectral bands | 198 | 159 selected from 242 |
| Acquisition dates | Bitemporal dataset | May 1, 2004 and May 8, 2007 |
| Ground truth | Binary | Binary + Multiclass |
| Classes | Change / No-change | 2 binary classes; 7 multiclass classes |
| Main changes | Sediment/sandbar exposure and water level | Crops, soil and other land-cover transitions |

---

# 7. References

## GETNET River Project

1. S. Liu, L. Bruzzone, F. Bovolo and P. Du, **"Hierarchical change detection in multitemporal hyperspectral images,"** *IEEE Transactions on Geoscience and Remote Sensing*, vol. 53, no. 1, pp. 244–260, 2015.  
   DOI: https://doi.org/10.1109/TGRS.2014.2320911

2. S. Liu, L. Bruzzone, F. Bovolo and P. Du, **"Unsupervised hierarchical spectral analysis for change detection in hyperspectral images,"** *2012 4th Workshop on Hyperspectral Image and Signal Processing: Evolution in Remote Sensing (WHISPERS)*, 2012.

3. H. Zhuang, Z. Tan, K. Deng and G. Yao, **"Change detection in multispectral images based on multiband structural information,"** *Remote Sensing Letters*, 9(12), pp. 1167–1176, 2018.

4. M. Hasanlou and S. T. Seydi, **"Hyperspectral change detection: an experimental comparative study,"** *International Journal of Remote Sensing*, 2018.

5. S. T. Seydi and M. Hasanlou, **"A new land-cover match-based change detection for hyperspectral imagery,"** *European Journal of Remote Sensing*, 50(1), pp. 517–533, 2017.

## Hyperion Agricultural Project

1. S. Liu, D. Marinelli, L. Bruzzone and F. Bovolo, **"A Review of Change Detection in Multitemporal Hyperspectral Images: Current Techniques, Applications, and Challenges,"** *IEEE Geoscience and Remote Sensing Magazine*, vol. 7, no. 2, pp. 140–158, 2019.  
   DOI: https://doi.org/10.1109/MGRS.2019.2898520

2. S. Liu, Q. Du, X. Tong, A. Samat, H. Pan and X. Ma, **"Band Selection based Dimensionality Reduction for Change Detection in Multitemporal Hyperspectral Images,"** *Remote Sensing*, vol. 9, no. 10, p. 1008, 2017.  
   DOI: https://doi.org/10.3390/rs9101008

3. S. Liu, L. Bruzzone, F. Bovolo and P. Du, **"Unsupervised Multitemporal Spectral Unmixing for Detecting Multiple Changes in Hyperspectral Images,"** *IEEE Transactions on Geoscience and Remote Sensing*, vol. 54, no. 5, pp. 2733–2748, 2016.  
   DOI: https://doi.org/10.1109/TGRS.2015.2505183

---

# License

This project is released under the **MIT License**.
