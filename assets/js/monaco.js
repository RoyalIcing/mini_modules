const monacoLoadPromise = new Promise(resolve => {
    window.monacoDidLoad = resolve;
});

async function loadMonacoIfNeeded() {
    const loaderURL = "https://unpkg.com/monaco-editor@latest/min/vs/loader.js";
    const scriptEl = document.querySelector(`script[src="${loaderURL}]`);
    if (scriptEl) {
        // We have already starting loading.
        await monacoLoadPromise;
        return;
    }

    await new Promise((onload, onerror) => {
        document.body.appendChild(Object.assign(document.createElement('script'), {
            // async: true,
            // defer: true,
            src: loaderURL,
            onload,
            onerror
        }))
    });

    document.body.appendChild(
        Object.assign(document.createElement('script'), {
            type: "module",
            // async: true,
            defer: true,
            innerText: `
            window.require.config({
                paths: {
                  'vs': 'https://unpkg.com/monaco-editor@latest/min/vs'
                }
              });
              const proxy = URL.createObjectURL(new Blob([\`
              self.MonacoEnvironment = {
                baseUrl: 'https://unpkg.com/monaco-editor@latest/min/'
              };
              importScripts('https://unpkg.com/monaco-editor@latest/min/vs/base/worker/workerMain.js');
            \`], { type: 'text/javascript' }));
            
            window.MonacoEnvironment = { getWorkerUrl: () => proxy };

            window.require(["vs/editor/editor.main"], function () {
                const typescript = monaco.languages.typescript;
                for (const lang of [typescript.typescriptDefaults, typescript.javascriptDefaults]) {
                  lang.setCompilerOptions({
                    noSemanticValidation: true,
                    noSyntaxValidation: false
                  });
                  lang.setCompilerOptions({
                    target: monaco.languages.typescript.ScriptTarget.ESNext,
                    allowNonTsExtensions: true,
                    allowJs: true,
                  });
                  /* FIXME: types.then(([uri, content]) => lang.addExtraLib(content, uri)); */
                }
                window.monacoDidLoad();
            });
            `,
        }));

    await monacoLoadPromise;
}

customElements.define('minimodules-monaco-editor', class MiniModulesMonacoEditorElement extends HTMLElement {
    constructor() {
        super();
        console.log("MiniModulesMonacoEditorElement constructor");
        // this.attachShadow({ mode: 'open' });

        this.isApplyingAttributeChange = false;
    }

    connectedCallback() {
        this.aborter = new AbortController();
    }

    disconnectedCallback() {
        this.aborter.abort();
    }

    get signal() {
        return this.aborter.signal;
    }

    static get observedAttributes() { return ['source', 'change-clock']; }

    attributeChangedCallback(name, oldValue, newValue) {
        if (name === 'change-clock' && oldValue !== newValue) {
            if (!this.editor) return;

            const source = this.getAttribute('source');
            const model = this.editor.getModel();
            if (model.getValue() !== source) {
                this.isApplyingAttributeChange = true;
                model.setValue(source);
                this.isApplyingAttributeChange = false;
            }
        }
        if (name === 'source') {
            console.log("attributeChangedCallback", name);
            if (this.editor) {
                console.log("HAS EDITOR");
                const model = this.editor.getModel();
                // if (model.getValue() !== newValue) {
                //     model.setValue(newValue);
                // }
            } else {
                this.loadIfNeeded(newValue);
            }
        }
    }

    loadIfNeeded(source) {
        if (this.loading) {
            return;
        }
        this.loading = true;

        loadMonacoIfNeeded().then(() => {
            const language = this.getAttribute('language') || 'javascript';
            // console.log(this.ownerDocument);
            // const div = this.shadowRoot.ownerDocument.createElement('div');
            const div = this.ownerDocument.createElement('div');
            div.style.width = "100%";
            div.style.height = "100%";
            this.appendChild(div);
            this.editor = window.monaco.editor.create(div, {
                language,
                model: monaco.editor.createModel(source, language, 'ts:worker.ts'),
                // value: newValue,
                theme: 'vs-dark',
                fontSize: 16,
                wordWrap: 'on',
                automaticLayout: true,
                minimap: {
                    enabled: false
                },
                scrollbar: {
                    vertical: 'auto'
                },
                formatOnType: true,
                formatOnPaste: true,
            });

            const form = this.closest("form");
            if (form) {
                form.addEventListener("formdata", event => {
                    const name = this.getAttribute('name');
                    const value = this.editor.getModel().getValue();
                    event.formData.append(name, value);
                }, { signal: this.signal });
            }

            this.editor.onDidChangeModelContent(() => {
                const value = this.editor.getValue();
                console.log("monaco did change", value);

                if (this.hasAttribute('name')) {
                    const form = this.closest("form");
                    if (form && !this.isApplyingAttributeChange) {
                        // Trigger formdata event
                        new FormData(form);
                    }
                }
                // const inputEl = this.querySelector('input[type="hidden"]');
                // console.log("monaco did change", value, inputEl);
                // this.dispatchEvent(new CustomEvent('input', { value, bubbles: true, cancelable: true }));
                // this.pushEvent("changed", { input: value });
                // inputEl.dispatchEvent(new CustomEvent('input', { value, bubbles: true, cancelable: true }));
                // inputEl.dispatchEvent(new CustomEvent('change', { value, bubbles: true, cancelable: true }));
            });

            // const resizeObserver = new ResizeObserver((entries) => {
            //     entries.forEach((entry) => {
            //         // Ignore hidden container.
            //         if (this.offsetHeight > 0) {
            //             this.editor.layout();
            //         }
            //     });
            // });
            // resizeObserver.observe(window);
        })
    }
});

export const MonacoHook = {
    async mounted() {
        await loadMonacoIfNeeded();

        const value = '// Hello World blah blah';

        this.editor = window.monaco.editor.create(this.el, {
            language: 'javascript',
            model: monaco.editor.createModel(value, 'javascript', 'ts:worker.ts'),
            // value,
            theme: 'vs-dark',
            fontSize: 16,
            minimap: {
                enabled: false
            },
            formatOnType: true,
            formatOnPaste: true,
        });
    },

    destroyed() {
        if (this.editor) {
            this.editor.dispose();
        }
    },
};
