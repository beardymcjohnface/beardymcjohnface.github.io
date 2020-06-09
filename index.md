---
layout: default
title: Home
---



{% assign post = site.posts.first %}

<h3><a href="{{ post.url }}">{{ post.title }}</a></h3>
<p>{{ post.date | date_to_string }}</p>
<details>
  <summary>
    {{ post.excerpt }}(<i>Click to expand</i>)
</summary>
  {{ post.content | remove: post.excerpt }}
</details>



{% for post in site.posts offset:1 limit:3 %}
  <br>
  <h3><a href="{{ post.url }}">{{ post.title }}</a></h3>
  <p>{{ post.date | date_to_string }}</p>
  <p>{{ post.excerpt }}</p>
{% endfor %}

<br>

### [All posts...](/archive)


