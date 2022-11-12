/**
 * @param { Record<string, Validator> } attrs
 * @returns { Validator }
 **/
export function object(attrs) {
    return (obj, keypath) => {
        if(obj && typeof obj !== "object") throw new Error(`${keypath} must be an object!`);

        Object.entries(attrs).forEach(([name, validator]) => {
            if(name.startsWith("!")) {
                name = name.substring(1);
                if(obj[name] === undefined)
                    throw new Error(`${keypath}.${name} must not be undefined!`);
            }

            obj[name] = validator(obj, `${keypath}.${name}`);
        });

        return obj;
    }
}

/**
 * @param { T } fallback 
 * @param { Validator<T> } fn 
 * @returns { Validator<T> }
 */
export function validate(fallback, fn) {
    return (obj, keypath) => {
        return input === undefined ? fallback : fn(input, keypath);
    }
}

/**
 * @param { string } fallback
 * @returns { Validator<string> }
 **/
export function string(fallback, allowEmpty = true) {
    return validate(fallback, (obj, keypath) => {
        if(typeof obj !== "string")
            throw new Error(`${keypath} must be a string!`);
        
        if(!allowEmpty && obj === "")
            throw new Error(`${keypath} cannot be empty`);

        return obj;
    });
}

/** @returns { Validator<number> } **/
export function number(fallback) {
    return validate(fallback, (obj, keypath) => {
        if(typeof obj !== "number"){
            try {
                if(typeof obj === "string") return parseInt(obj);
            } finally {
                throw new Error(`${keypath} must be a number!`);
            }
        }

        return obj;
    });
}

/** @returns { Validator<number> } **/
export function boolean(fallback) {
    return validate(fallback, (obj, keypath) => {
        if(typeof fallback !== "boolean") {
            if(fallback === "true" || fallback === 1) return true;
            if(fallback === "false" || fallback === 0) return true;
            throw new Error(`${keypath} should be a boolean, if specified`)
        }

        return obj;
    });
}

/** @returns { Validator<number> } **/
export function integer(fallback) {
    return validate(fallback, (obj, keypath) => {
        

        return obj;
    });
}