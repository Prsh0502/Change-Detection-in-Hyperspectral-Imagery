# Hyperspectral Change Detection — River Dataset (GETNET)
A hyperspectral dataset used for testing pseudo-binary and multi-class change detection techniques, along with a full change detection pipeline implemented using the MATLAB Hyperspectral Imaging Library.

## File Description
All dataset files are in `.mat` format and can be loaded in MATLAB. **Not included in this repository** (see Data Access below) — only the small ground truth file and this project's own outputs are included directly.

**_river_before_:** Hyperspectral image, date 1;

**_river_after_:** Hyperspectral image, date 2;

**_groundtruth_:** A binary reference map for evaluating change detection performance (two classes: change and no-change).

## Data Set Description
This dataset is made up of a pair of bitemporal hyperspectral images of a river region, each sized 463×241 pixels with 198 spectral bands. The major land-cover changes in this scenario are due to shifting sediment/sandbar exposure and water level between the two acquisition dates.

**Data Access:** The dataset is not included in this repository, as the raw `.mat` cubes are ~170 MB each and exceed GitHub's 100 MB file limit. Download the dataset from the GETNET benchmark source and place `river_before.mat`, `river_after.mat`, and `groundtruth.mat` in a `data/` folder before running the script in this repo.

## Images

![Before/After/Ground Truth](figures/before_after_groundtruth.png)

![Detected change overlay](figures/detection_accuracy_overlay.png)

(a) Before; (b) After; (c) Ground Truth; (d) Detected change overlay — green = correct, red = false alarm, yellow = missed

## Class Information

**_Change_**: 9,698 pixels

**_No-Change_**: 101,885 pixels

**_Total_**: 111,583 pixels

---

## Project: Change Detection Pipeline

This repository also includes a full change detection implementation (`change_detection_river.m`) built on the **Image Processing Toolbox™ Hyperspectral Imaging Library**, following a pseudo-binary detection → endmember extraction → hierarchical clustering → spectral matching pipeline. See `README_project.md` for full methodology, theory, and results, and `results.md` for the metrics table.

**Summary of results:**

| Method | OA | Precision | Recall | F1 | Kappa |
|---|---|---|---|---|---|
| Pseudo-binary (CVA + Otsu) | 75.19% | 0.244 | 0.887 | 0.383 | 0.286 |
| Final (Endmember + SAM + ambiguity resolution) | 85.39% | 0.302 | 0.521 | 0.382 | 0.306 |

## Citation

This project builds on techniques described in the following papers.

[1] S. Liu, L. Bruzzone, F. Bovolo and P. Du, "Hierarchical change detection in multitemporal hyperspectral images," IEEE Transactions on Geoscience and Remote Sensing, vol. 53, no. 1, pp. 244–260, 2015. [DOI: 10.1109/TGRS.2014.2320911](https://ieeexplore.ieee.org/document/6873380)

[2] S. Liu, L. Bruzzone, F. Bovolo and P. Du, "Unsupervised hierarchical spectral analysis for change detection in hyperspectral images," 2012 4th Workshop on Hyperspectral Image and Signal Processing: Evolution in Remote Sensing (WHISPERS), Shanghai, China, 2012.

[3] H. Zhuang, Z. Tan, K. Deng and G. Yao, "Change detection in multispectral images based on multiband structural information," Remote Sensing Letters, 9:12, pp. 1167–1176, 2018.

[4] M. Hasanlou and S. T. Seydi, "Hyperspectral change detection: an experimental comparative study," International Journal of Remote Sensing, 2018.

[5] S. T. Seydi and M. Hasanlou, "A new land-cover match-based change detection for hyperspectral imagery," European Journal of Remote Sensing, 50:1, pp. 517–533, 2017.
