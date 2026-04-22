---
title: "ManifoldNeRF: View-dependent Image Feature Supervision for Few-shot Neural Radiance Fields"
authors:
  - Daiju Kanaoka
  - Motoharu Sonogashira
  - Hakaru Tamukoh
  - Yasutomo Kawanishi
date: "2023-11-20T00:00:00Z"
publication_types: ["paper-conference"]
publication: "34th British Machine Vision Conference 2023 (BMVC2023)"
publication_short: "BMVC2023"
abstract: |
  Novel view synthesis has recently made significant progress with the advent of Neural Radiance Fields (NeRF). DietNeRF is an extension of NeRF that aims to achieve this task from only a few images by introducing a new loss function for unknown viewpoints with no input images. The loss function assumes that a pre-trained feature extractor should output the same feature even if input images are captured at different viewpoints since the images contain the same object. However, while that assumption is ideal, in reality, it is known that as viewpoints continuously change, also feature vectors continuously change. Thus, the assumption can harm training. To avoid this harmful training, we propose ManifoldNeRF, a method for supervising feature vectors at unknown viewpoints using interpolated features from neighboring known viewpoints.
  Since the method provides appropriate supervision for each unknown viewpoint by the interpolated features, the volume representation is learned better than DietNeRF.
  Experimental results show that the proposed method performs better than others in a complex scene. We also experimented with several subsets of viewpoints from a set of viewpoints and identified an effective set of viewpoints for real environments. This provided a basic policy of viewpoint patterns for real-world application.
tags:
  - Neural Radiance Fields
  - Few-shot Learning
featured: true
projects: []
slides: ""
---
