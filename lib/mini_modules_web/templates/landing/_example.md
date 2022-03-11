Use constants:

```js
export const pi = 3.14159265;
export const dateFormat = "YYYY/MM/DD";
export const isEnabled = true;
export const flavors = ["vanilla", "chocolate", "caramel", "raspberry"];
```

```json
{
  "pi": 3.14159265,
  "dateFormat": "YYYY/MM/DD",
  "isEnabled": true,
  "flavors": [
    "vanilla",
    "chocolate",
    "caramel",
    "raspberry"
  ]
}
```

Build URLs:

```js
export const homeURL = new URL("https://example.org/");
export const aboutURL = new URL("/about", homeURL);
export const blogURL = new URL("/blog/", homeURL);
export const firstArticle = new URL("./first-article", blogURL);
```

```json
{
  "homeURL": "https://example.org/",
  "aboutURL": "https://example.org/about",
  "blogURL": "https://example.org/blog/",
  "firstArticle": "https://example.org/blog/first-article"
}
```

Import modules:

```js
import { pi, homeURL } from "https://gist.github.com/BurntCaramel/d9d2ca7ed6f056632696709a2ae3c413/raw";
export { pi };
export { homeURL };
```

```json
{
  "pi": 3.14159265,
  "homeURL": "https://example.org/"
}
```
