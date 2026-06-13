const js = require("@eslint/js");

module.exports = [
    js.configs.recommended,
    {
        files: ["**/*.js"],
        ignores: ["node_modules/**"],
        languageOptions: {
            ecmaVersion: 2022,
            sourceType: "commonjs",
            globals: {
                require: "readonly",
                module: "writable",
                exports: "writable",
                process: "readonly",
                console: "readonly",
                Buffer: "readonly",
                URL: "readonly",
                setTimeout: "readonly",
                clearTimeout: "readonly",
                __dirname: "readonly",
            },
        },
        rules: {
            "no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
        },
    },
];
