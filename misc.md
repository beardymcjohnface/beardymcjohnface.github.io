---
layout: default
permalink: /misc
title: Misc Posts
---

## Misc posts

{% for post in site.posts %}
  <ul>
  {% if post.category == "misc" %}
    <li>
      <h3><a href="{{ post.url }}">{{ post.title }}</a></h3>
      <p>{{ post.date | date_to_string }}</p>
      <p>{{ post.excerpt }}</p>
    </li>
  {% endif %}
  </ul>
{% endfor %}
