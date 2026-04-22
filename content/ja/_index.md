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
      title: 主要業績
      text: ''
      count: 0
      filters:
        folders:
          - publications
        featured_only: true
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
  - block: resume-awards
    id: awards
    content:
      title: 受賞歴
      username: me_ja
  - block: resume-patents
    id: patents
    content:
      title: 特許
      username: me_ja
---
