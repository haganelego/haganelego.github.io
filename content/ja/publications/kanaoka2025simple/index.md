---
title: "Simple open-set recognition combining metric learning and anomaly detection"
authors:
  - Daiju Kanaoka
  - Yuichiro Tanaka
  - Hakaru Tamukoh
date: "2025-01-01T00:00:00Z"
publication_types: ["article-journal"]
publication: "*Advanced Robotics*, 39(7), 368-382"
publication_short: "Advanced Robotics"
abstract: |
  In real world scenarios, there is always a risk that an object recognition system will encounter unknown objects.
  Open-set recognition, which identifies such objects as "unknown," is a crucial research area.
  Most existing open-set recognition methods have complex structures.
  Considering the application of closed-set recognition models already used in the real world are utilized for open-set recognition, a simple structure is preferable for implementation.
  In this study, we propose a novel open-set recognition method that focuses on the feature space of a recognition model by combining metric learning and anomaly detection (AD).
  By applying metric learning, the feature vectors of the same class are clustered and those of different classes are separated, increasing the open space for the detection of unknown objects.
  The AD model trains on feature vectors from the intermediate layers of a recognition model, allowing unknown detection without altering the existing model structure.
  We evaluated various combinations of metric learning and AD techniques, identifying an effective pairing.
  Our results show that the proposed method performs comparably to state-of-the-art approaches on simple datasets.
  The simplicity of the proposed method makes it easy to adapt existing closed-set recognition models for open-set recognition in real-world applications.
tags:
  - Open-set Recognition
  - Metric Learning
featured: true
projects: []
slides: ""
---
