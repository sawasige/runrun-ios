const eslint = require("@eslint/js");
const tseslint = require("typescript-eslint");

module.exports = tseslint.config(
  {ignores: ["lib/**", "eslint.config.js"]},
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  {
    languageOptions: {
      parserOptions: {
        project: ["./tsconfig.json"],
        tsconfigRootDir: __dirname,
      },
    },
  },
);
