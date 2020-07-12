---
layout: default
title: Home
---


### Latest

{% assign post = site.posts.first %}

<h2><a href="{{ post.url }}">{{ post.title }}</a></h2>
<p>{{ post.date | date_to_string }}</p>
<details>
  <summary>
    {{ post.excerpt }}(<i>Click to expand</i>)
</summary>
  {{ post.content | remove: post.excerpt }}
</details>

<br>

### Recent

{% for post in site.posts offset:1 limit:3 %}
  <h3><a href="{{ post.url }}">{{ post.title }}</a></h3>
  <p>{{ post.date | date_to_string }}</p>
  <p>{{ post.excerpt }}</p>
{% endfor %}

<br>

### [All posts...](/archive)


