# markdown2html.bash

```
!!  PROJECT UNDER CONSTRUCTION  !!
```

Convert markdown to HTML with pure BASH

````bash
markdown2html.bash - <<'EOF'
# BASH Coding
How to print hello world:
```bash
#!/usr/bin/env bash
printf '%s\n' 'hello world'
```
EOF

````
stdout:
```html
<h1>BASH Coding</h1>
<p>
How to print hello world:<br />
</p>
<pre><code class="language-bash">
#!/usr/bin/env bash
printf '%s\n' 'hello world'
</code></pre>
```
## License
Licensed under GNU Affero General Public License v3. See LICENSE for details.
