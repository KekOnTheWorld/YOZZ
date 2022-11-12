/** @return {import('vite').Plugin} */
export function suv() {
    /** @type {import('vite').ConfigEnv} */
    let vite_config;

    return {
        name: "suv",
        async config(config, config_env) {
            console.log("CONFIG", config, config_env);
        },

        async load(id, options) {
            console.log("LOAD", id, options);
        },

        configResolved(config) {
            vite_config = config;
        },

        buildStart() {
            console.log("BUILD START");
        },

        writeBundle: {
            async handler(_options, bundle) {
                console.log("Writebundle called", _options, bundle);
            }
        }
    }
}