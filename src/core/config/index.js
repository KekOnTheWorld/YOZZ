import { promises as fs } from "fs";
import path from "path";
import url from "url";

export async function loadConfig({ cwd = process.cwd() } = {}) {
    const configFile = path.join(cwd, "suv.config.js");

    try { await fs.access(configFile, fs.constants.R_OK) } 
    catch(e) { return processConfig({ }, { cwd }) }
    
    const config = await import(`${url.pathToFileURL(configFile).href}?ts=${Date.now()}`);

    return processConfig(config.default, { cwd });
}

export function processConfig(config, { cwd = process.cwd() } = {}) {

}

export function validateConfig(config) {
    if(typeof config !== 'object')
        throw new Error("suv.config.js must have an default configuration object export!");
    
    return config;
}