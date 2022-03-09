export const WebComponentHook = Object.freeze({
    mounted() {
        this.aborter = new AbortController();
        const signal = this.aborter.signal;
        console.log("WebComponentHook", this.el);

        const form = this.el.closest("form");
        form.addEventListener("formdata", event => {
            const editor = this.el.editor;
            console.log(Array.from(event.formData.keys()));
            // console.log("formdata", this.el.editor);
            event.formData.append('input', editor.getModel().getValue());
        }, { signal });

        // this.el.addEventListener("input", (event) => {
        //     console.log("handleEvent", event);
        // });
    },

    destroyed() {
        this.aborter.abort();
    },
});
