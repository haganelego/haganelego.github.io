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
      title: Publications
      text: |-
        For more detail, please refer to [here](https://www.brain.kyutech.ac.jp/~tamukoh/achievement).
      filters:
        folders:
          - publications
        exclude_featured: false
    design:
      view: citation
  - block: resume-experience
    id: experience
    content:
      username: me
    design:
      date_format: 'January 2006'
      is_education_first: true
  - block: resume-awards
    id: awards
    content:
      title: Awards
      username: me
---
