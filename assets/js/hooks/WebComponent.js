export const WebComponentHook = Object.freeze({
    mounted() {
        this.aborter = new AbortController();
        const signal = this.aborter.signal;
        console.log("WebComponentHook", this.el);

        const form = this.el.closest("form");
        form.addEventListener("formdata", event => {
            // FIXME: this only works with the monaco editor
            const editor = this.el.editor;
            // event.formData.append(this.el.getAttribute('name'), editor.getModel().getValue());
            console.log(this.el.getAttribute('name'), Array.from(event.formData.keys()));
            // console.log(event.target)
            // event.target.submit();

            // event.target.dispatchEvent(
            //     new Event("submit", { bubbles: true, cancelable: true })
            // )

            // const form = event.target;
            // form.elements.event_lines.dispatchEvent(new Event("input", {bubbles: true}));

            // this.pushEvent("changed", Object.fromEntries(event.formData));
        }, { signal });

        // this.el.addEventListener("input", (event) => {
        //     console.log("handleEvent", event);
        // });
    },

    destroyed() {
        this.aborter.abort();
    },
});
