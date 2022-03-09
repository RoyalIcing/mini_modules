export const WebComponentHook = Object.freeze({
    mounted() {
        console.log("WebComponentHook", this.el);

        const form = this.el.closest("form");
        form.addEventListener("formdata", event => {
            const editor = this.el.editor;
            console.log(Array.from(event.formData.keys()));
            // console.log("formdata", this.el.editor);
            event.formData.append('input', editor.getModel().getValue());
        });

        // this.el.addEventListener("input", (event) => {
        //     console.log("handleEvent", event);
        // });
    }
});
