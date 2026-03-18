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
      username: me
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
      title: Featured Publications
      text: ''
      count: 0
      filters:
        folders:
          - publications
        featured_only: true
      archive:
        enable: true
        text: See all publications →
        link: /publications/
    design:
      view: featured-card
  - block: resume-experience
    id: experience
    content:
      username: me
    design:
      date_format: 'January 2006'
  - block: resume-awards
    id: awards
    content:
      title: Awards
      username: me
---
