---
layout: post
category: misc
---

If you're a data scientist/bioinformatician/whatever and are looking at making your own static website, you can't go wrong with [GitHub Pages](https://pages.github.com).
It's free, it's easy, and it's fast. 
There are plenty of tutorials on the subject and I'm not an expert, so, this is not a guide, just a breif showcase.

I first made a github page a few years ago for the [Adelaide Protein Group](https://apg.asn.au) for which I'm the webmaster.
The group started in 2008 as a special interest group of the [Australian Society for Biochemistry and Molecular Biology](https://www.asbmb.org.au/).
In the early years the APG needed the website to manage the event RSVP functionality, email newsletters etc. 
They settled on a traditional joomla website, spending a few hundred dollars per year for the domain and hosting.

In 2018 I built a new, slim website for the APG.
We had moved to collecting RSVPs using Eventbrite (free) and sending our newsletters with Mailchmip (free), so we no longer needed dynamic website hosting.
The new website is hosted using GitHub pages (also free), with DNS by cloudflare (you guessed it, free). 
The only thing we now pay for is the domain name (approx. $12/year). 
All in all, it saves a lot of money that is better spent on APG events.
It was a no-brainer.

I started by cloning the theme I wanted (minima for the APG, midnight for this blog).

```
git clone https://github.com/pages-themes/midnight.git
```

You could just create the repo and select a theme, the idea being you only need to add and modify a few files to make your website 
but I wanted to customise the look and funcionality.
For the APG website I made quite a few tweaks to change the look and feel, and to get a feel for the inner workings of jekyll.
For this site I just changed some colours and tweaked some other CSS, and tweaked the __default.html__ template file.

Jekyll has inbuilt support for blog posting. 
New blog posts simply go in a ___posts/__ directory with the format __yyyy-mm-dd-title.md__;
Jekyll automatically infers the date and title, creates a url for the post, and even grabs an excerpt from the content.
Some called 'front matter' goes at the top of this file:

```
---
layout: post
category: misc
---
```

- __layout:__ tells Jekyll what template html to use for rendering the page.
- __category:__ is a custom label that lets us filter posts further down. 

The post template __posts.html__ I had to create, but it simply builds on the theme's default template to show the contents of the post:

```{% raw %}
---
layout: default
---

<h1>{{ page.title }}</h1>
<p>{{ page.date | date_to_string }}</p>

{{ content }}
{% endraw %}```


I already knew the structure that I wanted so I went ahead and added the pages as well as links for the nav bar:

- __about.md__: A simple 'about me' page.
- __projects.html__: Posts for finished projects.
- __misc.html__: Miscellaneous blog posts.
- __archive.html__: List of all posts.

These pages are implicitly available at __/about__, __/projects__ etc. but you can also manually set the permalinks within those files,
for instance to make __silly-file-name.html__ accessible at __/sensible/url__.

Finally, add some code (thanks google) to cycle over posts and display a list of links, for instance in __projects.html__:

```{% raw %}
{% for post in site.posts %}
    <ul>
    {% if post.category == "project" %}
        <li>
          <h2><a href="{{ post.url }}">{{ post.title }}</a></h2>
          <p>{{ post.date | date_to_string }}</p>
          <p>{{ post.excerpt }}</p>
        </li>
    {% endif %}
    </ul>
{% endfor %}
{% endraw %}```

So as you can see there's only a handful of steps you need to do to set up the site's files and make it your own.
Deployment is easy, just dump the files in your GitHub pages repo, and push. 
Your site is now published at __reponame.github.io__.
Setting up a custom domain takes a few extra steps:

- purchase domain name
- configure A and CNAME records on cloudflare, point to github
- point domain registry name servers at cloudflare
- add domain name in the github repo's settings, and to repo file called __CNAME__

That's basically all there is!
Adding posts is easy; locally I just create a new file in ___posts/__, give it a category and add the content as markdown. 
Test the website locally to make sure it looks fine:

```
bundel exec jekyll serve
```

Commit the changes and push, and the website gets automtically rebuilt by GitHub.
As you can see, you get a fair amount of website for very little cost and effort.




