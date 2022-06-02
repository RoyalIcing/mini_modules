export const PushEventOnFormDataHook = Object.freeze({
    mounted() {
        this.aborter = new AbortController();
        const signal = this.aborter.signal;

        const form = this.el.closest("form");
        form.addEventListener("formdata", event => {
            const eventName = this.el.getAttribute('phx-value-event');

            // Allow other listeners to have added to FormData.
            queueMicrotask(() => {
                this.pushEvent(eventName, Object.fromEntries(event.formData));
            });
        }, { signal });

        // this.el.addEventListener("input", (event) => {
        //     console.log("handleEvent", event);
        // });
    },

    destroyed() {
        this.aborter.abort();
    },
});
