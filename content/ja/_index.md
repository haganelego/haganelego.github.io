---
title: ''
summary: ''
date: 2022-10-24
type: landing

design:
  spacing: '2rem'

sections:
  - block: resume-biography-3
    id: about
    content:
      username: me_ja
      text: ''
    design:
      name:
        size: md
      avatar:
        size: medium
        shape: circle
  - block: collection
    id: publications
    content:
      title: 最近の業績
      text: ''
      count: 5
      filters:
        folders:
          - publications
      archive:
        enable: true
        text: すべての業績を見る →
        link: /publications/
    design:
      view: featured-card
  - block: resume-experience
    id: experience
    content:
      username: me_ja
    design:
      date_format: '2006年1月'
---
