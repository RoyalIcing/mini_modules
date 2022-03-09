const mermaidLoadPromise = new Promise(resolve => {
    window.mermaidDidLoad = resolve;
});
function loadMermaid() {
    if (document.getElementById('mermaid-js')) {
        return mermaidLoadPromise;
    }

    const script = document.createElement('script');
    script.id = 'mermaid-js';
    script.defer = true;
    script.type = 'module';
    script.innerHTML = `
        import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@8.13.10/dist/mermaid.esm.min.mjs";
        window.mermaidDidLoad(mermaid);
    `;
    document.body.appendChild(script);
    return mermaidLoadPromise;
}

customElements.define('mermaid-image', class MermaidImageElement extends HTMLElement {
    constructor() {
        super();
        this.attachShadow({ mode: 'open' });
    }

    static get observedAttributes() { return ['source']; }

    attributeChangedCallback(name, oldValue, newValue) {
        if (name === 'source') {
            loadMermaid().then(mermaidAPI => {
                mermaidAPI.render('blah', newValue, (svgSource) => {
                    this.shadowRoot.innerHTML = svgSource;
                });
            });
        }
    }
});
