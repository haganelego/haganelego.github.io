---
title: "A Memory-Efficient Long-Term Human Behavior Representation for Behavior History Retrieval"
authors:
  - Daiju Kanaoka
  - Yasutomo Kawanishi
date: "2026-01-01T00:00:00Z"
publication_types: ["paper-conference"]
publication: "8th International Conference on Activity and Behavior Computing (ABC2026)"
publication_short: "ABC2026"
abstract: |
  Understanding human behavior patterns through observing long-term behavior in real-world environments is a crucial function for service robots.
  However, achieving sustainable long-term observation and behavioral understanding is difficult because the robots should continuously accumulate observation data while operating under strict limitations on onboard computational and memory resources.
  A technical difficulty in this task is that long-term observation inevitably increases stored data, which leads to memory overflow unless the system can reduce data volume while preserving essential behavioral patterns.
  In human memory mechanisms, a process known as chunking organizes continuous or periodically recurring experiences into meaningful units, allowing efficient storage and retrieval of essential information while redundant details are discarded.
  Inspired by the mechanism, we propose a memory-efficient framework for understanding long-term human behavior.
  The proposed method achieves memory efficiency by accumulating behavioral data, such as the locations and times observed by the robot, and compressing it by consolidating multiple redundant behavioral data into a single representative data.
  Additionally, we propose a memory retrieval system that takes a time or date as a query and visualizes relevant behavioral data as a heatmap to identify important locations at the specified time.
  Experimental results using simulated human behavior data demonstrate that this method reduces the memory required to store behavioral information by approximately 80%, while maintaining accuracy comparable to a method that stores all behavioral data naively.
tags:
  - Behavior Recognition
featured: true
projects: []
slides: ""
---
