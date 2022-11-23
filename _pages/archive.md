---
layout: default
permalink: /archive/
title: Archive
---

## Archive

{% for post in site.posts %}
  <ul>
    <li>
      <h3><a href="{{ post.url }}">{{ post.title }}</a></h3>
      <span>{{ post.date | date_to_string }}</span>
    </li>
  </ul>
{% endfor %}
