// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket


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
        this.attachShadow({mode: 'open'});
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
