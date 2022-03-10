```js
// Use constants:
export const pi = 3.14159265;
export const dateFormat = "YYYY/MM/DD";
export const isEnabled = true;
export const flavors = ["vanilla", "chocolate", "caramel", "raspberry"];

// Generate URLs:
export const homeURL = new URL("https://example.org/");
export const aboutURL = new URL("/about", homeURL);
export const blogURL = new URL("/blog/", homeURL);
export const firstArticle = new URL("./first-article", blogURL);
```

```json
{
  "aboutURL": "https://example.org/about",
  "blogURL": "https://example.org/blog/",
  "dateFormat": "YYYY/MM/DD",
  "firstArticle": "https://example.org/blog/first-article",
  "flavors": [
    "vanilla",
    "chocolate",
    "caramel",
    "raspberry"
  ],
  "homeURL": "https://example.org/",
  "isEnabled": true,
  "pi": 3.14159265
}
```
