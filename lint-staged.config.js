module.exports = {
    '*.{js,jsx,ts,tsx}': [
        'eslint --fix',
        'prettier --write',
        'git add',
    ],
    '*.{json,md,yaml,yml}': [
        'prettier --write',
        'git add',
    ],
    '*.{css,scss,sass}': [
        'prettier --write',
        'git add',
    ],
    'package.json': [
        'sort-package-json',
        'git add',
    ],
};